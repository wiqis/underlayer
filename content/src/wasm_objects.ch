// WebAssembly Course — Module 5: Objects
// Concept: the object format — custom sections the core specification does not
// define, the 5-byte LEB128, and what a linker needs to know.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_objects() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Objects, Linking and Relocations — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>Objects, Linking and Relocations</h1>
            <div class="lesson-meta">23 min &middot; Module 5: Objects &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything so far has described a finished module: a self-contained thing a host can validate and run. But a compiler does not produce finished modules. It produces <strong>object files</strong> that refer to functions defined elsewhere, and something has to join them together &mdash; and that something needs information the core format has no place for.</p>
                <p>Where does that information go? <strong>Into custom sections, which the core specification does not define at all.</strong> A custom section is section id 0, and its payload begins with a name. The specification's entire requirement is that a reader which does not recognise the name skip it &mdash; which it can, because the section size is right there. Everything after the name is somebody else's format.</p>
                <p>This is the single most important architectural fact about the object format, and it is worth understanding as a design position rather than a shortcut. The core specification did not need to know about symbol tables or relocations, so it did not define them, so <strong>a runtime that only implements the core can load any object file without erroring</strong> &mdash; it ignores what it does not know. Compare <a href="/courses/pe/lessons/pe-imports">a PE file</a>, where a runtime either understands the import directory or produces a broken image, or <a href="/courses/dwarf/lessons/dwarf-dies">DWARF</a>, where the debugging information is in sections with declared ids that a non-debugging reader still has to know to skip. The custom section is the format saying: <em>you do not need to know me, and I will not pretend you do.</em></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The custom section itself, and it is a three-line structure:</p>
                <div class="formula">
custom section:
    section_id 0x00
    size                            bytes in the payload
    name                            a length-prefixed UTF-8 string
    contents                        name.length() and size.length() are
                                    somebody else's problem
</div>
                <p>Three real object files, and the custom sections they contain. This is a complete listing of what <code>wasm-objdump</code> reports, so nothing is hidden:</p>
                <div class="hex-dump">
                    <pre>  simple.o     7 sections
    Type, Import, Function, Code, and custom:
      "linking"           0x20 = 32 bytes
      "producers"         0x38 = 56 bytes
      "target_features"   0x94 = 148 bytes

  externs.o    10 sections
    Type, Import, Function, DataCount, Code, and custom:
      "linking"           46 bytes
      "producers"
      "target_features"

  externs.o also has, when relocations are needed:
      "reloc.CODE"        17 bytes
</pre>
                </div>
                <p>Four names, and they divide cleanly by purpose. <strong><code>linking</code> holds the symbol table</strong> &mdash; every function and data item the object defines or needs, so a linker can resolve between objects. <strong><code>reloc.CODE</code> holds the relocations</strong>, one custom section per section that needs them, named after the section they patch. <strong><code>producers</code> records who built the file</strong>, and <strong><code>target_features</code> records what the code requires</strong> &mdash; which features were used, so a linker or runtime can reject code using features it cannot support.</p>
                <p>The naming convention for the relocation sections is the detail worth noticing: <code>reloc.CODE</code> means "relocations against the code section", and there would be a <code>reloc.DATA</code> if a data segment needed patching. <strong>The name is the addressing scheme.</strong> It is a convention rather than something the format enforces, which is both its weakness and its flexibility &mdash; a producer can invent <code>reloc.</code> plus any section name and the core will skip it just the same.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The 5-byte LEB128, which is the finding that will bite you first</h3>
                <p>Here is the first eight bytes of a real object file, produced by LLVM 21:</p>
                <div class="hex-dump">
                    <pre>0000: 00 61 73 6d 01 00 00 00 00 85 80 80 80 00
      |                    |  |  |  |  +-- 0x00: high byte, no more bits
      |                    |  |  |  +----- 0x80: continuation, zero bits
      |                    |  |  +-------- 0x80: continuation, zero bits
      |                    |  +----------- 0x80: continuation, zero bits
      |                    +-------------- 0x85: low 7 bits = 5, continuation
      +------------------------------------- 0x00: section id = CUSTOM
</pre>
                </div>
                <p>Read the version field first: <code>01 00 00 00</code> &mdash; <strong>the 32-bit version is written as four plain bytes, not a LEB128</strong>, which is correct and specified. Now the section size at <code>0x8</code>: <code>85 80 80 80 00</code>. That is <strong>five bytes</strong> encoding the value 5, where one byte would do. And it is not a one-off:</p>
                <div class="hex-dump">
                    <pre>  every section in externs.o, with the width of its size LEB128:

    0x08   5 bytes      0x13   5 bytes      0x31   5 bytes
    0x39   5 bytes      0x40   5 bytes      0x56   5 bytes
    0x66   5 bytes      -> the linking section

  all eight. Not one of them uses a minimal encoding.
</pre>
                </div>
                <p><strong>A producer may pad a LEB128 out to the maximum width for its type.</strong> <code>85</code> and <code>05</code> are the same number; the specification says the value is what matters, not the width. LLVM emits the full five bytes for every <code>u32</code>, because it writes the value with a fixed-width encoder that happens to be a LEB128 algorithm, and a constant-time encoder is easier to get right than a variable-time one.</p>
                <div class="callout callout-warn">
                    <strong>And this is the trap that a reader written against the smallest examples in this course will fall into.</strong> The <a href="/courses/wasm/lessons/wasm-leb128">LEB128 concept</a> and the <a href="/courses/wasm/lessons/wasm-sections">section framing</a> both work on hand-built minimal files, where a section size is one byte. A decoder written that way and tested only against them will read <code>85 80 80 80 00</code>, compute 5, and then <strong>be one byte out of position immediately</strong> &mdash; it will treat <code>0x80</code> as the start of the next section. The failure is not subtle and not rare: <em>every single section of every LLVM-produced object triggers it</em>. Three readers were used to verify this course, and all three read these files correctly, so the specification's intent is unambiguous; the point is that a decoder has to be written against the specification's <em>rule</em> rather than against the shortest input that satisfies it, and <strong>the shortest satisfying input is exactly the one that never appears in a real toolchain's output.</strong>
                </div>
                <h3>The linking section's structure</h3>
                <p>Confirmed by an independent walk of the bytes:</p>
                <div class="hex-dump">
                    <pre>  0066: 00 ae 80 80 80 00 07 6c 69 6e 6b 69 6e 67
        |  |  |  |  |  |  |  +-- "linking", 7 characters
        |  |  |  |  |  |  +----- name length = 7
        |  |  |  |  |  +----------- payload starts here
        |  |  |  |  +--------------- 5-byte size LEB128 = 46
        |  |  |  +------------------- 0x00 = CUSTOM section
        +------------------------------ 0x66 = the section starts here

  0074: 02                    version = 2
  0075: 08                    subsection id 8  = the SYMBOL TABLE
  0076: 8f 80 80 80 00        subsection size = 15   &lt;- ALSO five bytes
  007b: 02                    symbol count = 2
</pre>
                </div>
                <p><strong>Three layers of the same structure</strong>, and the repetition is the design working: a subsection is a section, which is an id, a size, and a payload. The subsection size is <em>also</em> a five-byte LEB128, so the padding convention is applied at the inner level too. A reader that handles the outer level correctly and the inner one with a minimal-encoding assumption will fail twice as deep into the file, which is the kind of bug that only shows up once you have a nested length-prefixed structure to walk.</p>
                <p>And wabt's own reading of the symbol table, which is authoritative for the semantics even though this course could not fully reconcile the record layout from a single sample:</p>
                <div class="hex-dump">
                    <pre>  - 0: F &lt;sum&gt; func=0 [ binding=global vis=hidden ]
  - 1: D &lt;g&gt; segment=0 offset=0 size=4 [ binding=global vis=hidden ]

  segment info [count=1]
   - 0: .bss.g p2align=2
</pre>
                </div>
                <p>Read the properties and the analogy to every other format's symbol table is exact. <strong><code>F</code> and <code>D</code> are the kind</strong> &mdash; a function, a data item &mdash; and the index is the section-relative number. <strong><code>binding=global</code> versus <code>local</code></strong> is the internal-linkage distinction, exactly as <a href="/courses/coff/lessons/coff-symbol-table">a COFF <code>StorageClass</code></a> or an <a href="/courses/elf/lessons/symbol-table">ELF symbol binding</a> distinguishes them. <strong><code>vis=hidden</code> means "not exported to the world"</strong> &mdash; the same concept as <a href="/courses/coff/lessons/coff-weak-externals">a COFF symbol being static</a> rather than external, and the reason a linker will not put <code>sum</code> in the export table. And a data symbol carries <strong>segment, offset and size</strong>, which is the triple an <a href="/courses/elf/lessons/section-header-table">ELF symbol's <code>st_value</code> and <code>st_size</code></a> carry between them.</p>
                <div class="callout callout-warn">
                    <strong>What this course verified, and what it did not.</strong> The section framing, the five-byte LEB128 at both levels, the version, the subsection structure, the subsection id, the symbol count, the first symbol's complete byte layout, the segment-info subsection, and the relocation record below are all verified against the raw bytes and confirmed by a second reader. <strong>The exact field order within a data symbol's record is not.</strong> Walking the fifteen bytes of the symbol table with a length-prefixed name lands the first symbol exactly, then the second leaves two bytes unaccounted for: the arithmetic is off by a field, and the walk desynchronises. The observable symptom is the cleanest possible evidence, and it is worth recording precisely because it is the failure this course has been warning about since the first concept. After the desync, the parser reported <strong>subsection ids 2, 4 and 3</strong> where the raw bytes at <code>0x8a</code> plainly say <strong>5</strong>. Those are small plausible integers, so nothing errored; the parser simply kept reading the wrong fields and produced entirely fictional subsections. That is what a length-prefixed structure looks like when a record inside it is mis-sized, and it is why the discipline is to walk records and to check your position against the enclosing size rather than to trust that a sequence of plausible values is a sequence of correct values. <strong>No claim about the data symbol's field order is made here.</strong>
                </div>
                <h3>The relocation record</h3>
                <p>The smallest and most legible of the object sections, and a complete reading of it:</p>
                <div class="hex-dump">
                    <pre>   - name: "reloc.CODE"
    - relocations for section: 4 (Code) [1]
     - R_WASM_MEMORY_ADDR_LEB offset=0x000007(file=0x00004d) symbol=1 &lt;g&gt;
</pre>
                </div>
                <p>Four facts and nothing else, and the names say what each one is for. <strong>The section index says which section is being patched</strong> &mdash; section 4, the code section, because this object is a relocatable one where the code section is id 4 rather than 10. <strong>The relocation type says what kind of fix-up to apply</strong>, and <code>MEMORY_ADDR_LEB</code> is the important one: an address that must be written as a LEB128 into a code section, so the patch has to be a <em>signed</em> LEB128 of the right width, and a linker that wrote a fixed-width value would corrupt the instruction stream. <strong>The offset is where in that section to patch</strong>, and the parenthetical is the same number in file coordinates. <strong>The symbol index says what to patch it with</strong> &mdash; symbol 1, which the symbol table names as <code>g</code>, the data item in <code>.bss.g</code>.</p>
                <p><strong>That one relocation type is the whole reason a linker can process code, not just data.</strong> A relocation into a data section patches a fixed-width field and nothing has to move. A relocation into a <em>code</em> section patches a variable-width one, so the linker must know the value before it can size the patch, and the patch can change the file's length. This is a genuinely harder problem than the data case, it is the reason the object format has a <em>separate custom section per relocatable section</em> rather than one relocation table, and it is the same class of problem as <a href="/courses/pe/lessons/pe-base-relocations">a PE base relocation</a> needing to know the width of the field it is patching. The difference is that the WebAssembly case is worse, because a wrong width does not produce a wrong address &mdash; it produces a <em>misaligned instruction stream</em> that may still decode as something plausible.</p>
                <h3>target_features</h3>
                <p>The last custom section, and the smallest idea. It is 148 bytes in <code>simple.o</code> and wabt reports its presence without expanding it, so this course records what it is for rather than what its bytes mean. Its job is to declare which proposals the code actually uses &mdash; and that is a real safety property, not metadata for its own sake. <strong>A runtime can reject an object whose feature list it does not implement, at load time, rather than accepting it and hitting an unknown opcode mid-execution.</strong> It is the object-format equivalent of the <a href="/courses/wasm/lessons/wasm-tables-memories">limits flags</a> rule: a producer declares what it needs so a consumer can refuse cleanly instead of misreading.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a linker actually does with these three sections, and why the order matters more than the content:</p>
                <div class="formula">
<pre>
link(a.o, b.o) -> out.wasm:

    # 1. GATHER. Every object contributes a symbol table from its
    #    "linking" section. Build one global namespace:
    #      defined here          -> this object owns the definition
    #      undefined in both     -> an error, or resolved from an import
    #      undefined in one      -> resolve to the other object's definition
    #      defined in both       -> a duplicate, unless they are COMDAT groups

    # 2. RELOCATE. For each object's reloc.CODE / reloc.DATA:
    #      for each relocation:
    #          value = the resolved symbol's address in the OUTPUT
    #          if the type is a LEB128 patch into CODE:
    #              THE PROBLEM: encoding the value may need more bytes
    #              than the placeholder reserved
    #              -> either the producer must reserve slack, or the
    #                 linker must rewrite the instruction stream
    #          write value at the recorded offset, at the recorded width

    # 3. DISCARD. Drop the "linking", "reloc.*" and "target_features"
    #    sections. The output is a MODULE, and a module has no symbol
    #    table -- the whole point of linking is that the result needs none.

    # 4. WRITE, in ascending section-id order, per the module format.
</pre>
                <p><strong>Step 3 is the one that shows what the object format is for.</strong> A finished WebAssembly module has no symbol table, no relocations and no unresolved names &mdash; that is the property that makes it safe to hand to an untrusted runtime, and it is exactly what steps 1 and 2 produce. <strong>The object format exists to hold the intermediate state that the module format deliberately cannot represent</strong>, and it holds it in sections the module format ignores, so that a reader of the output needs to know nothing about the input's provenance.</p>
                <p>Step 2 is where this course's biggest limit sits, and it should be stated rather than glossed. <strong>No <code>wasm-ld</code> or <code>lld</code> is available in this environment</strong>, so linking behaviour could not be observed: the code in that block is derived from the relocation record's structure and from the width problem it implies, not from a linked output. The one thing that <em>was</em> verified is the input side &mdash; the relocation record, the symbol table, the section names &mdash; because those are in files on disk. <strong>A reader that wants to see the output side needs a linker installed, and the exercise below says exactly what to check when they have one.</strong></p>
                <p>Step 1's duplicate case connects to a lesson from another course in this collection, and it is worth naming because it is the same mechanism reached from a different direction. <a href="/courses/coff/lessons/coff-comdat-linking">A COFF linker's COMDAT handling</a> discards a duplicate section based on its <em>name</em>, ignoring the checksum, and silently produces wrong code when two same-named sections differ. WebAssembly's object format has COMDAT groups too, in a dedicated <code>linking</code> subsection &mdash; and the same failure is available to it, because a group is identified by a name and the format's job is deduplication rather than verification. <strong>Every deduplication-by-name mechanism can discard something that should have been kept, and the only defence is a checksum that is actually checked.</strong></p>
            </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -x externs.o
$ clang --target=wasm32 -c -O0 -o sym.o sym.c
$ python3 courses/wasm/assets/samples/wasm_decode.py externs.o</code></pre>
                <ul>
                    <li><strong>Measure the padding, do not assume it.</strong> Write a hexdump of the first sixteen bytes of a freshly compiled object and read the section size LEB byte by byte. Then do it for a hand-built file with <code>wat2wasm</code>, which emits minimal encodings, and compare. <strong>Two producers, same format, five bytes versus one, and every decoder in this course has to handle both</strong> &mdash; which is exactly why the sample set contains both kinds of file.</li>
                    <li><strong>Break your own decoder the way a real object will.</strong> Take the course's decoder, make it assume minimal LEB128, and run it on <code>externs.o</code>. Then make it handle non-minimal encodings and run it again. <strong>Doing this on purpose is the point: the first version will look like it works on the hand-built samples and will fall apart on the real one</strong>, and that is the failure mode you want to recognise rather than discover.</li>
                    <li><strong>Reconcile the symbol record, or record that you could not.</strong> Take the fifteen bytes of <code>externs.o</code>'s symbol table and try every plausible field order until all fifteen are accounted for and the next subsection id reads 5. If you cannot, you have reproduced this course's exact result &mdash; <strong>and the two unaccounted bytes plus the wrong downstream ids are the evidence of where it went wrong.</strong> A negative result with a documented symptom is worth more than a guess.</li>
                    <li><strong>Compare the section ids between an object and a module.</strong> <code>externs.o</code> has its code section as id 4; a finished module has it as id 10, because the element and datacount sections are absent from the object. Dump both and account for the difference. <strong>Relocatable files do not share the module's section layout</strong>, and a reader that assumes they do will reject every object it meets.</li>
                    <li><strong>Find a file that needs a relocation and one that does not.</strong> A single <code>.c</code> file with no globals and no external calls produces no <code>reloc.CODE</code>. Add a global variable and it appears. <strong>Two compiles, one section, and a clear picture of what makes a relocation necessary</strong> &mdash; the object format is not paying for relocations it does not need.</li>
                    <li><strong>Install a linker and close this course's biggest gap.</strong> With <code>wasm-ld</code> available, link two objects where one calls the other's function, and read the result: the symbol table and reloc sections should be gone, the callee should be a direct <code>call</code> with no import, and the function indices should have been renumbered. <strong>Then read the <a href="/courses/wasm/lessons/wasm-imports">import section</a> of the output and see whether any imports survived</strong> &mdash; that is the part this course could not observe, and it is the last thing standing between an understanding of the format and an understanding of the toolchain.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a section's size field in a real LLVM object file is the five bytes <code>85 80 80 80 00</code>. What number does it encode, is the encoding legal, and what does a decoder that reads one byte and moves on do with the rest of the file?</p>
                <div class="quiz" id="quiz-wasm-objects-1">
                    <button class="quiz-option" data-correct="true" data-explain="Every LEB128 byte contributes its low seven bits shifted by a multiple of seven, and a byte with the high bit clear ends the value. So 0x85 contributes 5 with continuation set, the three 0x80 bytes each contribute zero with continuation set, and the final 0x00 contributes zero and stops. The total is 5, and the encoding is legal because LEB128 constrains the value, never the width -- a width up to the number of bits in the type is permitted, and five bytes is the maximum for a 32-bit value. A decoder that reads only the first byte gets 5 and advances one position instead of five, so it treats the next 0x80 as a section id. The consequence is not a subtle misread: every section in the file is misaligned, so the second section's size is read from the wrong place and the walk compounds. This is why the course's hand-built samples, which use minimal encodings, are the dangerous ones -- they are the only inputs on which the minimal assumption looks correct, and real toolchain output is the only input on which it does not." onclick="checkQuiz('quiz-wasm-objects-1', this)">It encodes 5. The encoding is legal, because LEB128 fixes the value and not the width, and five bytes is the maximum for a 32-bit field. A one-byte reader gets the right number, advances one position instead of five, and misaligns the entire rest of the file</button>
                    <button class="quiz-option" data-correct="false" data-explain="The value is not 133, and the reason is exactly the point the question is testing. 133 would be the result of ignoring the continuation bits -- treating the leading 0x85 as 0x85 and the following bytes as fresh fields rather than as higher-order digits of the same number. LEB128's continuation bit is what marks those bytes as belonging to the same value, and a format that ignored it would not be a compact encoding but a fixed-width one. The illegal-encoding claim is also wrong: padding a LEB128 out to the full width of its type is permitted, and it is what LLVM does for every section size in every object file it emits." onclick="checkQuiz('quiz-wasm-objects-1', this)">It encodes 133, and the encoding is illegal because a LEB128 must be minimally encoded, so a conforming reader should reject this file</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your module loader validates every module a compiler produces and rejects a fraction of them with a generic "section out of order" error. Modules assembled with <code>wat2wasm</code> load perfectly. Nothing in your code branches on anything unusual, and you have never tested against an object file before. What is the defect, and why is the error message actively misleading about where to look?</p>
                <div class="quiz" id="quiz-wasm-objects-2">
                    <button class="quiz-option" data-correct="true" data-explain="The test matrix told you where to look before you read a line of the code. Every passing sample was hand-built with minimal LEB128 encodings, so the bug is only reachable on input that never appeared in the tests -- which is a property of the test suite, not of the code, and it is the reason a decoder has to be written from the specification's rule rather than from the observed shapes. The defect is that your LEB128 reader stops after one byte, or equivalently assumes the encoding is minimal, so it gets the right value and the wrong position. Everything after that first section size is read from an offset of four bytes, and because the misalignment is a constant and section ids are small integers, each subsequent id looks like a plausible but wrong number. That is why the error says 'out of order': your reader believes section 11 came before section 10, because it read a byte that is not a section id at all. So the message names the symptom in terms of the format's rules when the actual fault is in the primitive that produces the numbers the rules are checked against. The general habit is to read an error message as a claim about your parser, not as a claim about the file, and to ask what would have to be true of the input for that message to be accurate. Here the answer is 'a file with non-minimal LEB128', which is most real toolchain output, and no amount of reading the section-ordering rule would have found it." onclick="checkQuiz('quiz-wasm-objects-2', this)">Your LEB128 reader assumes minimal encodings and stops after one byte, so every section size in a real object leaves you four bytes out of position. The 'out of order' message names the symptom in terms of section ordering when the fault is in the number decoder, so it points at the wrong layer</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the conclusion the passing test matrix argues against. If your reader ignored the custom sections entirely, the modules would still fail, because the section table walk itself is what misaligns -- the first custom section's five-byte size LEB is consumed as one byte, and the walk desynchronises before any name is examined. And wat2wasm-produced files loading perfectly is the opposite of the signature of a custom-section bug, since wat2wasm output has custom sections too. The discriminating fact is which family of inputs fails, and it points at a difference in how the sizes are encoded rather than at which sections are present." onclick="checkQuiz('quiz-wasm-objects-2', this)">Your loader treats custom sections as part of the module body instead of skipping them by their declared size, so it tries to parse the linking data as declarations</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: the input family that works is evidence about the code, not reassurance. When a bug appears only on inputs your tests never contained, the test suite's assumptions are the defect &mdash; and an error message that names a format rule is pointing at a layer above wherever the fault actually is.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The custom section is the cleanest architectural decision in this format, and the collection has a spectrum of alternatives to measure it against. At one end, <a href="/courses/coff/lessons/coff-section-table">COFF</a> and <a href="/courses/elf/lessons/section-header-table">ELF</a> assign <em>meaning</em> to section ids: a COFF reader that meets section 1 knows it is text and a reader that meets an unassigned number has a malformed file, so extension requires the specification to grow. In the middle, <a href="/courses/dwarf/lessons/dwarf-dies">DWARF</a> reserves a large id space and documents that unknown ids must be skipped &mdash; the same intent as a custom section, expressed as an id range rather than as a name. At the WebAssembly end, <strong>a custom section is uninterpreted by construction</strong>, which means extension needs no specification change at all, and it also means there is nothing to validate. <strong>That trade &mdash; zero cost to add, zero guarantees from the core &mdash; is why the object format could be specified by other people without the core changing.</strong></p>
                <p>The relocation model connects most closely to <a href="/courses/pe/lessons/pe-base-relocations">PE base relocations</a>, and the similarity is instructive. Both patch addresses into already-placed code, both must know the width of the field they are writing, and both are the reason a linker can produce a working image without understanding the instructions. The differences are where the difficulty lives: a PE relocation patches a fixed-width field, so its size is known from the relocation type alone, while a <code>MEMORY_ADDR_LEB</code> relocation patches a variable-width encoding <em>inside an instruction stream</em>, so the linker must know the value before it can size the patch, and a width mistake yields a valid-looking but misaligned instruction stream rather than a wrong address. <strong>The variable-width case is strictly harder, and it is the direct consequence of the compact immediate encodings the instruction format chose.</strong> The same class of problem appears in <a href="/courses/pe/lessons/pe-imports">the PE import directory</a>, where a thunk's target is patched after the fact, and in <a href="/courses/coff/lessons/coff-relocations">COFF's <code>IMAGE_REL_I386_REL32</code></a>, which is fixed-width precisely because it is patching x86 code.</p>
                <p>The five-byte LEB128 is the thread back to <a href="/courses/wasm/lessons/wasm-leb128">the LEB128 concept</a>, and it is the best single lesson in the course about how variable-width encodings interact with real producers. A format's encoding rules are a permission, not an obligation, and a producer with a legitimate reason to pad will pad. The failure is entirely on the reader, and it is invisible until real toolchain output meets a decoder written against the smallest legal examples. <strong>Write decoders against the widest legal input, not the shortest</strong> &mdash; and the best way to find the widest is to look at what the tools in the ecosystem actually emit, which is why this course's sample set deliberately contains hand-built and compiler-built files side by side.</p>
                <p>That closes the format. A WebAssembly module is a magic number, a version, and thirteen section kinds in a fixed order, with every size a LEB128, every index relative to an import-first space, and every instruction a one-byte opcode with the top four bits reserved for the future. The object format wraps that in custom sections the core ignores, and a linker removes them. <a href="/courses/wasm/lessons/wasm-intro">Back to the beginning</a> to see the whole thing as one shape.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-data">Previous: The Data Section and DataCount</a></span>
                <span><a href="/courses/wasm/lessons/wasm-intro">Back to the start of the course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
