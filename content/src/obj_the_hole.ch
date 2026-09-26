// Object Files — Module 1: Why Object Files Exist
// Concept: the one mechanism the whole format exists for — an unresolved
// reference left in the bytes, plus the record that describes how to fill it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_the_hole() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Hole and a Record — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>A Hole and a Record</h1>
            <div class="lesson-meta">20 min &middot; Module 1: Why Object Files Exist &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Last concept: an object file knows where its holes are. This one is about what a hole physically is, and the answer is stranger than "a zero".</p>
                <p>Consider a call on x86-64. The instruction that calls a function <em>directly</em> is five bytes: a one-byte opcode followed by a four-byte <strong>relative</strong> displacement. The CPU computes the target as <code>address of the next instruction + displacement</code>. That is not a location, it is an <em>offset from somewhere that is only meaningful once the code is placed</em> &mdash; and at this point nobody knows where the code goes.</p>
                <p>So the compiler writes <strong>zero</strong> into those four bytes and emits a relocation saying <em>these four bytes are not a displacement yet</em>. Not "are probably zero". Not "are a placeholder you may ignore". <strong>They are wrong, deliberately, and the file says so in a table the linker reads before it does anything else.</strong></p>
                <p>Get this one concept right and the rest of the format is bookkeeping. Get it wrong &mdash; treat a relocation as an optimisation hint, or as a patch to apply at compile time &mdash; and you cannot write a linker at all, which is where this collection is heading.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A relocation record, at its most abstract. Every format in this course carries these same four ingredients, whatever it calls them:</p>
                <div class="formula">
  a relocation answers four questions:

    1. WHERE      which bytes are wrong
    2. HOW MUCH   how many bytes are wrong
    3. HOW        what arithmetic turns them right
    4. WHOM       relative to which symbol

  and one ELF record answers them in exactly that order:

    u64  r_offset     WHERE    offset into the section's contents
    u64  r_info       HOW+WHOM type in the high 32 bits,
                               symbol index in the low 32
    i64  r_addend     an extra constant, usually 0 in an object

  24 bytes. That is the whole record.
</div>
                <p>Question 3 is the one people skip, and it is the reason there are forty relocation types per architecture rather than one. <strong>The arithmetic is not always addition.</strong> For the call above it is <code>S + A - P</code>, where <code>S</code> is the symbol's final address, <code>A</code> the addend, and <code>P</code> the place being patched &mdash; because the field holds a <em>relative</em> offset and must have the instruction's own address subtracted out. For a 64-bit pointer in a data section it is just <code>S + A</code>, absolute, with no <code>P</code> anywhere.</p>
                <p>So <strong>"how" is a small enum, and the enum is per-architecture</strong> &mdash; <code>R_X86_64_PC32</code> is not the same enum as <code>R_AARCH64_JUMP26</code>, and neither resembles <code>IMAGE_REL_AMD64_REL32</code> or <code>X86_64_RELOC_BRANCH</code>. Four names for the same idea, three incompatible numbering schemes. This is the subject of the relocation tables concept; the point here is that the concept of "how" is why a linker needs an architecture plugin.</p>
                <div class="callout">
                    <strong>Why the record lives outside the bytes it describes.</strong> A relocation could be stored in a header at the front of the section, as a table of offsets. All three formats instead store it in a <em>separate section</em> &mdash; <code>.rela.text</code> in ELF, a list inside the section header in COFF, a <code>relocation</code> entry in Mach-O. The reason is practical: a tool streaming through <code>.text</code> wants the code bytes contiguous and cache-friendly, and interleaving variable-length records would make that impossible. <strong>The cost is that you cannot find a hole by scanning the bytes &mdash; you have to join two tables by offset.</strong>
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>One relocation, from this course's 1952-byte <code>demo_elf.o</code>, out of the four against <code>.text</code>:</p>
                <div class="hex-dump">
                    <pre>  OFFSET           TYPE                     VALUE
  0000000000000004 R_X86_64_PC32            global_counter-0x4
  000000000000000a R_X86_64_PC32            uninitialised-0x4
  0000000000000021 R_X86_64_PLT32           external_fn-0x4
  0000000000000033 R_X86_64_PC32            message-0x4
</pre>
                </div>
                <p>Take the first and answer all four questions from that one line.</p>
                <ul>
                    <li><strong>WHERE</strong> &mdash; <code>0x04</code>, an offset into <code>.text</code>'s contents. <code>.text</code> starts at file offset <code>0x40</code> and is 62 bytes long, so this is the fifth byte of code.</li>
                    <li><strong>HOW MUCH</strong> &mdash; four bytes, implied by the name: <code>PC32</code> is a 32-bit PC-relative field. <strong>The width is in the type name, not in a separate field.</strong> COFF makes the same choice for its common relocations; Mach-O splits it into a separate byte, which is one of several reasons its records are bigger.</li>
                    <li><strong>HOW</strong> &mdash; <code>PC32</code> means <code>S + A - P</code>. Absolute, and the addend is 0 in the record, so it computes to <code>S - P</code>.</li>
                    <li><strong>WHOM</strong> &mdash; <code>global_counter</code>, a symbol index in the low half of <code>r_info</code>.</li>
                </ul>
                <p>And now the part that surprises everyone, visible in that one line: <strong>the <code>-0x4</code> at the end is not part of the symbol name.</strong></p>
                <div class="hex-dump">
                    <pre>  global_counter-0x4     is really:  global_counter, with the
                            contents at .text+4 currently holding -4

  the disassembler prints it that way so you can see the value
  that will be ADDED to the contents. The real field is -4.

  why -4?  because the instruction is 4 bytes long, and the
            displacement is measured from the END of the
            instruction. So a correct displacement already has
            the instruction's own length subtracted out.
</pre>
                </div>
                <p>So the four bytes at <code>.text+4</code> are <strong>minus four</strong>, not zero, and the linker adds <code>S</code> and gets the right answer. <strong>The addend lives in the bytes, and it is a real number that the compiler computed</strong> &mdash; this is the addends concept, and it is where most first attempts at an object-file writer go wrong.</p>
                <h3>What the call looks like, and why PLT32 is different</h3>
                <p>Offset <code>0x21</code> is a call to <code>external_fn</code>, a symbol defined in neither this file nor any file it knows about. Its type is <code>R_X86_64_PLT32</code>, not <code>R_X86_64_PC32</code> &mdash; <strong>and the difference is a promise about the future, not a different calculation.</strong></p>
                <div class="hex-dump">
                    <pre>  R_X86_64_PC32     patch 4 bytes, S + A - P
  R_X86_64_PLT32   patch 4 bytes, S + A - P   AND tell the linker
                                             this might need a
                                             PLT entry

  the arithmetic is IDENTICAL. The extra bit is a hint: "if I
  end up calling into a shared library, build me a PLT stub and
  point at that instead."

  and COFF has no such distinction in an object file at all --
  demo_coff.o's call is a plain IMAGE_REL_AMD64_REL32, the same
  record as its data reference.
</pre>
                </div>
                <p><strong>Same arithmetic, different bookkeeping, and one format has no concept of it.</strong> That is worth sitting with, because it is the first evidence of something that runs through the whole course: a relocation type is not only an instruction to patch bytes, it is also <em>a piece of information for the linker's later decisions</em>. A linker that implements only the arithmetic and ignores the hint will produce a binary that crashes on the first call into a shared library.</p>
                <h3>The same four bytes, three formats</h3>
                <p>And the same reference, as each format records it &mdash; which is the comparison that makes the concept stick:</p>
                <div class="hex-dump">
                    <pre>  ELF     r_offset=0x04  r_info=(4&lt;&lt;32)|sym  r_addend=0
          a 24-byte record in its own section, .rela.text

  COFF    10 bytes, stored in the section header:
            VirtualAddress  0x000000000004
            SymbolTableIndex  0x0000000C
            Type              IMAGE_REL_AMD64_REL32
          no addend field AT ALL -- implicit, always

  Mach-O  8 bytes in a scattered list:
            r_address  0x04          an OFFSET, not a section address
            r_symbolnum  0x0C
            r_pcrel=1  r_length=2  r_extern=1  r_type=X86_64_RELOC_SIGNED
          width and arithmetic in FLAG BITS, not a type number
</pre>
                </div>
                <p>Three records, 42 bytes total, describing one four-byte hole. And Mach-O's is the most compact because it packs the arithmetic and the width into single bits &mdash; <code>r_pcrel</code> and <code>r_length</code> &mdash; rather than enumerating every combination as a type number. <strong>That is a genuine design trade, not an oversight: an enum costs nothing to read but grows without bound, while bit fields stay fixed and push the work onto the reader.</strong> A linker author needs both approaches, and needs to know which one each format chose before writing the arithmetic.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What this costs in practice, measured. Take the one line of C that produces a hole, and follow it through to the instruction bytes:</p>
                <div class="formula">
  demo.c, one line:

    return helper(a) + private_counter
           + global_counter + uninitialised;

  becomes, in demo_elf.o, inside .text:

      becomes this, in demo_elf.o, inside .text -- the real
      disassembly, byte for byte:

        0000 &lt;compute&gt;:
           0: 01 ff                    addl %edi, %edi     2 bytes
           2: 03 3d 00 00 00 00        addl (%rip), %edi   6 bytes
                                      ^^^^^^^^
           8: 8b 05 00 00 00 00        movl (%rip), %eax   6 bytes
                                      ^^^^^^^^
           e: 01 f8                    addl %edi, %eax     2 bytes
          10: 83 c0 03                 addl $0x3, %eax     3 bytes
          13: c3                       retq                1 byte

        0020 &lt;call_out&gt;:
          20: e9 00 00 00 00           jmp 0x25            5 bytes
                                      ^^^^^^^^
        0030 &lt;use_data&gt;:
          30: 48 8b 05 00 00 00 00     movq (%rip), %rax   7 bytes
                                          ^^^^^^^^

      the four ^^^^^^^^ markers sit at .text offsets 0x04, 0x0a,
      0x21 and 0x33 -- which are EXACTLY the four offsets the
      relocation records named. Each one is the trailing 4-byte
      disp32 of a RIP-relative instruction:

        6 bytes:  03 3d | 00 00 00 00     opcode 2, disp 4
        5 bytes:  e9    | 00 00 00 00     opcode 1, disp 4
        7 bytes:  48 8b 05 | 00 00 00 00  REX, opcode, disp 4

      and notice what is NOT there: no relocation for private_counter.
      It is a file-local int initialised to 3, so the compiler folded
      it into the immediate at 0x10 -- addl $0x3. Only a static's
      value can be folded this way; a global's cannot, because
      another translation unit may change it.

  </div>
                <p><strong>The hole is in the middle of a seven-byte instruction, not after it.</strong> That single fact is the reason this concept is harder than it looks and the reason instruction encodings are a prerequisite for writing a linker. A relocation is not "a pointer in the code" &mdash; it is a field <em>at a specific bit offset inside</em> an instruction encoding, and the linker must know the encoding to know it is allowed to write there.</p>
                <p>Now the AArch64 version of the same source, which is the comparison that makes the cost concrete:</p>
                <div class="hex-dump">
                    <pre>  x86-64 ELF, 4 relocations in .text:

    0004  R_X86_64_PC32             global_counter
    000a  R_X86_64_PC32             uninitialised
    0021  R_X86_64_PLT32            external_fn
    0033  R_X86_64_PC32             message

  AArch64 ELF, 8 relocations in .text -- SAME SOURCE:

    0000  R_AARCH64_ADR_PREL_PG_HI21   global_counter
    0004  R_AARCH64_LDST32_ABS_LO12_NC global_counter
    0008  R_AARCH64_ADR_PREL_PG_HI21   uninitialised
    000c  R_AARCH64_LDST32_ABS_LO12_NC uninitialised
    0020  R_AARCH64_JUMP26             external_fn
    0024  R_AARCH64_ADR_PREL_PG_HI21   message
    0028  R_AARCH64_LDST64_ABS_LO12_NC message
    (+ one more, for .rodata)
</pre>
                </div>
                <p><strong>Eight records where x86-64 needs four, for identical C.</strong> Nothing about the language, the source, or the linker changed. AArch64's <code>adrp</code> instruction carries a 21-bit <em>page</em> delta and its paired load carries a 12-bit <em>offset within the page</em>, in two different encodings &mdash; so one reference needs two fixups, one per field.</p>
                <div class="callout callout-warn">
                    <strong>Why this is the most important finding in the module.</strong> A learner who assumes "a relocation is a reference" will build a data structure with one entry per symbol reference, and it will be wrong on every AArch64 object &mdash; producing a linker that silently mis-resolves half its references on the most common server architecture on Earth. The correction is one sentence long and changes the shape of the code: <strong>a relocation is a reference to a <em>field</em>, not to a symbol</strong>. Two fields of one reference are two relocations, and nothing in the file tells you they are related. The pairing is a convention the <em>instruction encoder</em> knows and the linker must honour, which is why this course spends a module on encodings before it spends one on writing a linker.
                </div>
                <p>And a practical detail that bites anyone writing a tool: <strong>relocation offsets are not always sorted.</strong> In <code>demo_elf.o</code> and <code>demo_coff.o</code> they ascend. In <code>demo_macho.o</code> the four <code>.text</code> relocations come out as <code>0x37, 0x26, 0x0e, 0x08</code> &mdash; <strong>descending</strong>, which is a real Mach-O invariant rather than an artifact of this compiler. A tool that binary-searches a relocation list, or streams it once assuming monotonicity, produces correct-looking output on two formats and quietly wrong output on the third.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ llvm-objdump-21 -r -d courses/obj/assets/samples/demo_elf.o
$ llvm-objdump-21 -r -d courses/obj/assets/samples/demo_arm64elf.o</code></pre>
                <ul>
                    <li><strong>Find all four records and answer the four questions for each.</strong> Where, how wide, how, whom. <strong>Then read the disassembly and confirm each offset lands inside an instruction rather than after one</strong> &mdash; that check is what turns "a relocation is a pointer" into "a relocation is a field inside an encoding".</li>
                    <li><strong>Read the four bytes at <code>.text+4</code> as a little-endian signed 32-bit integer.</strong> It is <strong>-4</strong>, not zero, and understanding why the compiler put the instruction's own length there is the single most useful thing in this concept. Write the arithmetic for <code>R_X86_64_PC32</code> out loud with the numbers filled in.</li>
                    <li><strong>Count records per source reference on both architectures.</strong> Four on x86-64, eight on AArch64, same C file. <strong>Then find the pairing</strong> &mdash; which two records belong to one reference &mdash; and notice that nothing in either file records the pairing. It is a convention you have to know.</li>
                    <li><strong>Look at the record sizes.</strong> ELF 24 bytes, COFF 10, Mach-O 8. <strong>Decide where each of the 24 goes</strong> &mdash; and notice that Mach-O spends 2 of its 8 bytes on <code>r_length</code> and <code>r_pcrel</code>, which ELF spends a whole type number on. That is the enum-versus-bitfield trade, visible.</li>
                    <li><strong>Confirm the Mach-O ordering claim.</strong> <code>llvm-objdump-21 -r demo_macho.o</code> and check the offsets descend. Then write five lines of code that assume ascending order and run them on all three files. <strong>It works on two and is wrong on one</strong>, which is the worst possible failure and the reason to check.</li>
                    <li><strong>Write the ELF record by hand.</strong> A 24-byte <code>Elf64_Rela</code> that patches <code>.text+4</code> against <code>global_counter</code> as <code>PC32</code>, spliced into a copy of the file. <strong>Then link it with <code>ld.bfd</code> and read the result</strong> &mdash; the oracle answers immediately, and it is the smallest complete loop in the course.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an ELF object has one <code>R_X86_64_PC32</code> record at offset 4 of <code>.text</code>, against symbol <code>global_counter</code>, with <code>r_addend = 0</code>. The four bytes at <code>.text+4</code> currently read <code>00 00 00 fc</code>. What do those four bytes mean, what will the linker compute, and what is the relationship between that computed value and the symbol's final address?</p>
                <div class="quiz" id="quiz-obj-the-hole-1">
                    <button class="quiz-option" data-correct="true" data-explain="Those bytes are -4 as a little-endian signed 32-bit integer, and they are the implicit addend -- the disassembler is showing you symbol-minus-4 precisely because it wants you to see the value that will be added. The linker computes S plus A minus P, where S is the symbol's final address, A is the explicit addend from the record which is zero here, and P is the address of the place being patched. That gives S minus P, and since the stored value is -4 the result is S minus P minus 4, which is correct because a PC-relative displacement is measured from the end of the instruction rather than its start, and the instruction is four bytes of displacement plus one of opcode. The relationship to the symbol's address is therefore not 'the value of the symbol' but 'the distance from this instruction's end to the symbol' -- a distance, not an address, and only meaningful once the linker has placed both. That is the whole reason the field cannot be filled in by the compiler: the compiler knows the instruction is five bytes but does not know where the instruction or the symbol will end up. The trap worth naming is treating the stored bytes as an offset to add, when they are a correction to subtract before adding." onclick="checkQuiz('obj-the-hole-1', this)">They are -4, the implicit addend. The linker computes S + A - P with A = 0, giving S - P - 4, which is a <em>distance</em> from the end of the instruction to the symbol rather than an address &mdash; correct only because a displacement is measured from the end of the encoding, and the encoding is five bytes</button>
                    <button class="quiz-option" data-correct="false" data-explain="The arithmetic is right and the reading of the stored bytes is wrong, in a way that produces a link error rather than a crash -- which is why it is worth being precise. fc ff ff ff is -4, not 4294967292 in any sense that matters, and it is not a placeholder for zero. A tool that treats those bytes as an unsigned offset adds roughly four billion to the symbol's address and writes a nonsense displacement, so the program does not fail to link; it links cleanly and then jumps somewhere impossible at run time. That is a far worse outcome than a rejected file, and it is the reason the signedness of this field is worth teaching explicitly. The second error is treating the stored value as the thing to add. It is a correction: the linker adds it to S - P, and it is already negative precisely because the displacement is measured from the end of the instruction, so the length has been pre-subtracted." onclick="checkQuiz('obj-the-hole-1', this)">They are an unsigned 32-bit placeholder meaning 'not yet filled in', and the linker adds the symbol's address to them directly, producing S - P because the field is PC-relative</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing the relocation application pass of a linker. It reads the ELF records for <code>demo_arm64elf.o</code> and, for each one, computes <code>S + A - P</code> and writes the low 32 bits. On x86-64 objects it is correct. On AArch64 objects it links without error and every call goes to a wrong address, while data references are sometimes right. What is the model of "a relocation" that your implementation assumed, and what is the smallest change to the data structure that fixes it without making the x86-64 path slower?</p>
                <div class="quiz" id="quiz-obj-the-hole-2">
                    <button class="quiz-option" data-correct="true" data-explain="The implementation assumed one relocation per reference, which is true on x86-64 and false on AArch64, and the failure signature confirms it exactly. Calls go wrong because the AArch64 call relocation is a JUMP26 -- a 26-bit field measured from the instruction's own address, and a low-32-bits write cannot even express the signed 26-bit range correctly, so the target is garbage. Data references are sometimes right because the ADR_PREL_PG_HI21 record writes a 21-bit page delta, which has to be combined with the paired low-12-bit record before either means anything; writing them independently leaves one record's contribution missing, so the result is wrong whenever both halves are needed and accidentally right when one is zero. The fix is to stop keying anything on symbol references and key on fields, storing relocations as an indexed list per section with a stable index that pairs can refer to, so the AArch64 encoder can attach two field records to one reference and the linker can resolve and combine them as a unit. The x86-64 path does not get slower because it still has one record per reference; it just stops being the only shape the data structure has to allow. The general lesson is that a data structure designed around the simplest case will be silently wrong on the general one, and the tell is a bug that links cleanly and fails at run time." onclick="checkQuiz('obj-the-hole-2', this)">It assumed a relocation is a reference to a symbol, and a relocation is really a reference to a <em>field</em> inside an instruction. Key the storage on fields with a stable index so a pair can be joined, and keep the single-record case as the trivial instance &mdash; the x86-64 path is unchanged</button>
                    <button class="quiz-option" data-correct="false" data-explain="The diagnosis is a real class of bug and it is the wrong one here, because the evidence points at the arithmetic rather than the pairing. If the implementation were writing the correct 32-bit result and only failing to combine the two halves, the symptom would be a wrong-but-close address, because each half on its own contributes something to the intended sum. Instead every call is wrong, and calls are exactly the case with a single relocation on both architectures -- R_X86_64_PLT32 and R_AARCH64_JUMP26 are one record each. A pairing bug cannot explain a category of failure that has one record on both targets; a width and sign problem can, and it explains the other half of the evidence too, since a 32-bit write cannot represent a signed 26-bit field. There is also a practical reason to rule this out: changing the index scheme to allow pairing touches every consumer of the relocation list, while the actual defect is a two-line change in one function, so starting with the index scheme would be the more expensive way to be wrong." onclick="checkQuiz('obj-the-hole-2', this)">The implementation assumed relocations are sorted by offset and applied them in file order, so on AArch64 the paired ADR and LDST records land in the wrong order. It should sort the relocation list by offset before applying, which is a no-op on x86-64</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a data structure shaped around the simplest case will be silently wrong on the general one, and the tell is a bug that links cleanly and fails at run time. Key on the thing the format actually varies &mdash; here, the field &mdash; not on the thing that happens to be simple.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>A relocation is a work order deferred to link time, and that is the same shape as an <a href="/courses/elf/lessons/relocation-entries">ELF relocation</a> in a linked binary &mdash; same four questions, different answers. The ELF course teaches the executable side, where <code>r_addend</code> is meaningful and the symbol's address is already known. Here the addresses are unknown and the arithmetic cannot even be set up. <strong>Learning the record once and meeting it in both places is the efficient order, and the object version is the harder one because it is the one that has to be designed rather than consumed.</strong></p>
                <p>The COFF and Mach-O courses teach the same record for their own formats, and the comparison here is what makes them stick. <a href="/courses/coff/lessons/coff-relocations">COFF's 10-byte relocation</a> lives inside the section header rather than a section of its own, and has <strong>no addend field at all</strong> &mdash; the addend is always implicit and always in the bytes. <a href="/courses/macho/lessons/macho-relocations">Mach-O's 8-byte relocation</a> packs the arithmetic and width into flag bits. Three placements, three ways of saying "how", and one conclusion worth carrying: <strong>a format's relocation design is a statement about what its linker needs to be fast</strong>, because all three of these choices exist to let the linker walk a section's relocations without branching on a type number.</p>
                <p>That connects straight to the architecture section. AArch64's doubling is not a format quirk; it follows from an instruction encoding that splits an address into a 21-bit page delta and a 12-bit offset. And that is the same fact the architecture course teaches as the x86-64/AArch64/RISC-V encoding spectrum &mdash; variable-length versus fixed 32-bit versus fixed-with-compressed. <strong>The object file's relocation vocabulary is downstream of the instruction set's encoding choices, and once you see that, the forty relocation types stop looking like arbitrary enumeration and start looking like a direct transcription of which fields each instruction leaves for the linker to fill.</strong></p>
                <p>The "hole and a record" idea is also the collection's recurring shape, and it is worth naming as a pattern rather than a coincidence. A <a href="/courses/elf/lessons/relocation-entries">relocation</a> is a hole plus a record. A <a href="/courses/pe/lessons/pe-base-relocations">PE base relocation</a> is a hole plus a record. A <a href="/courses/elf/lessons/loader">PLT entry</a> is a hole filled lazily plus a record. A GOT slot is a hole filled by the loader plus a record. <strong>In every case the record says what would make the hole right, and in every case the arithmetic is deferred to whoever can finally know the answer.</strong> A learner who has internalised this pattern will find dynamic linking largely self-explanatory, because dynamic linking is the same trick applied one step later, to a file that is already finished.</p>
                <p>One practical note, because it is the kind of thing that costs an afternoon. The four bytes you inspected are <strong>little-endian on x86-64</strong>, so <code>00 00 00 fc</code> is -4 and not 0x000000fc. Every one of these formats is little-endian on this target, which is <em>not</em> a property of the formats &mdash; it is a property of the targets, and it is why the <a href="/courses/jvm/lessons/jvm-header">JVM class file</a> course opens with "everything here is big-endian, including the magic number" as a contrast. <strong>The one field that tells you the byte order is the magic number at offset 0, and you read it before you read anything else.</strong> The <a href="/courses/elf">ELF</a>, <a href="/courses/coff">COFF</a> and <a href="/courses/macho">Mach-O</a> courses each cover this for their own format.</p>
                <p>Next: one source, three formats &mdash; the whole specimen set compared, to separate what an object file must have from what each format merely chose.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-intro">Previous: The Middle of Every Build</a></span>
                <span>Next: One Source, Three Formats</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
