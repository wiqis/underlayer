// Object Files — Module 3: The Fixup
// Concept: where the constant half of a relocation value lives. Implicit in
// the section bytes, explicit in the record, or supplied by the relocation
// type's definition -- and the three things a disassembler prints that all
// look like "the value" and are not.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_addends() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Addend Lives in the Bytes — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>The Addend Lives in the Bytes</h1>
            <div class="lesson-meta">20 min &middot; Module 3: The Fixup &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/obj/lessons/obj-relocations">The previous concept</a> decoded a relocation record and found an <code>r_addend</code> of <code>-4</code> sitting next to four zero bytes in the section it patches. That looks contradictory. <strong>It is not, and the reason is the single most consequential difference between the three formats in this module: two of them put the addend in the record, one puts it in the bytes, and a third hides it in the relocation type's definition.</strong></p>
                <p>Here is the whole problem in one command's output. This is real, from <code>llvm-objdump-21 -r</code> on the staged specimen:</p>
                <div class="hex-dump">
                    <pre>  RELOCATION RECORDS FOR [.text]:
  OFFSET           TYPE                     VALUE
  0000000000000004 R_X86_64_PC32      global_counter-0x4
  0000000000000021 R_X86_64_PLT32          external_fn-0x4
  0000000000000033 R_X86_64_PC32             message-0x4
</pre>
                </div>
                <p>That <code>-0x4</code> is not part of any symbol name, and reading it as one is the mistake almost everyone makes the first time. <strong>It is the addend, and the disassembler is showing you a value that is not in the file at all &mdash; it is in the relocation record, which the disassembler is choosing to display next to the name.</strong></p>
                <div class="callout callout-warn">
                    <strong>And here is the correction this concept exists to make, because it is the intuitive answer and it is wrong.</strong> The natural guess is that <code>-0x4</code> lives in the four bytes of <code>.text</code> at offset 4, because that is where a displacement normally goes. In <code>demo_elf.o</code> those four bytes are <code>00 00 00 00</code>. <strong>The <code>-4</code> is in <code>r_addend</code>, in the record, and the bytes are zero because a relocatable object has no addresses to put there.</strong> Building the 32-bit counterpart of the same source &mdash; which uses <code>REL</code> instead of <code>RELA</code> and therefore has no addend field &mdash; is what makes the contrast visible, because there the <code>-4</code> really is in the bytes.
                </div>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Start from the arithmetic, because the addend only makes sense as part of it. The general shape of a relocation's value is:</p>
                <div class="formula">
  value  =  S  +  A  -  P          and then the field-specific
                                   transformation, if any

  S   the address (or offset) of the symbol
  A   the ADDEND: a constant that is not derivable from S
  P   the address of the field being patched
</div>
                <p><code>A</code> exists because <code>S - P</code> is not always the whole answer. Three reasons a format needs it, in increasing order of how often they bite:</p>
                <ul>
                    <li><strong>Instruction-length bias.</strong> A PC-relative displacement is measured from the <em>end</em> of the instruction, but <code>P</code> is the field's address, which is inside it. The distance from the field to the instruction's end is a property of the encoding, known at compile time and <strong>identical for every single PC-relative relocation in the file</strong>. This is the <code>-4</code>, and it is by far the most common addend you will meet.</li>
                    <li><strong>Structure offsets.</strong> <code>int *p = &amp;arr[3];</code> needs <code>A = 12</code>. The symbol gives you <code>arr</code>; the constant 3 is the programmer's, and nothing else in the file records it.</li>
                    <li><strong>Absolute positions in a PIC binary.</strong> In a position-independent executable the base is unknown at link time, so the linker's own output address is a <em>relative</em> displacement with a known bias. Again, a constant, again per-encoding.</li>
                </ul>
                <p>Now the design question, and it has exactly two answers a format can give:</p>
                <div class="formula">
  IMPLICIT   the section bytes already contain A.  The producer
             writes S_local + A into the field, where S_local is
             the symbol's offset within its own section.  The
             linker REPLACES the field with S + A - P.

  EXPLICIT   the record carries A in a field of its own.  The
             section bytes are left zero.  The linker computes
             S + A - P and writes it.

  Both are correct.  They differ in where the constant is stored,
  and that difference has real consequences in both file size and
  reader complexity.
</div>
                <p><strong>The consequence worth understanding is this: under the implicit scheme, the section bytes are <em>wrong</em> until the link happens.</strong> They contain a value computed against a section-relative symbol address that is only correct if the symbol stays exactly where the producer put it. Move the section during linking and every pre-filled field is stale. Under the explicit scheme the bytes are simply zero, which is never wrong, and the linker writes the real value once.</p>
                <div class="callout callout-tip">
                    <strong>Which is why RELA exists and why it is not simply "better".</strong> The explicit form costs a field &mdash; 8 bytes per record on ELF64, so <code>demo_elf.o</code>'s four <code>.text</code> records are 96 bytes where the <code>REL</code> form would be 32. <strong>It buys correctness under section reordering, and it is the reason a 64-bit ELF object is measurably larger than the 32-bit one for the same source.</strong> The trade was made in favour of explicit, and modern 64-bit targets use it universally. The 32-bit x86 target still does not, which is why the same source produces <code>REL</code> records there and the contrast is still observable on any machine.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Case one: ELF64 with RELA &mdash; the addend is in the record</h3>
                <p>The first <code>.rela.text</code> record of <code>demo_elf.o</code> and the four bytes it patches, side by side. Bytes from the file at <code>0x40</code> (<code>.text</code>) and <code>0x240</code> (the record):</p>
                <div class="hex-dump">
                    <pre>  .text at 0x40                    the record at 0x240
  00000040: 01ff 033d 0000 0000        00000240: 0400 0000 0000 0000
                     ^^^^^^                                0200 0000 0500 0000
                  the four bytes                           fcff ffff ffff ffff
                  the patch targets      ^^^^^^^^ the -4, as a signed i64

  These are EIGHT ZERO BYTES AT DIFFERENT PLACES.  The
  displacement field is zero and the addend is -4.  Nothing
  in the section says what the displacement should be; the
  record says what to add to it.
</pre>
                </div>
                <p>So the answer to &quot;where does the <code>-0x4</code> the disassembler printed come from&quot; is: <strong>from <code>r_addend</code> at offset 16 of the record, and from nowhere else.</strong> And <code>readelf -rW</code> shows both halves at once, which is the clearest single view of the concept:</p>
                <div class="hex-dump">
                    <pre>  Offset             Info             Type     Symbol's Value  Symbol's Name + Addend
  0000000000000004  0000000500000002 R_X86_64_PC32  0000000000000000 global_counter - 4
  000000000000000a  0000000600000002 R_X86_64_PC32  0000000000000000 uninitialised  - 4
  0000000000000021  0000000800000004 R_X86_64_PLT32 0000000000000000 external_fn    - 4
  0000000000000033  0000000a00000002 R_X86_64_PC32  0000000000000008 message        - 4
</pre>
                </div>
                <p>Read the columns as the three quantities of the model. <strong>&quot;Symbol's Value&quot; is <code>S</code>, and it is 0 for the three undefined symbols and 8 for <code>message</code> &mdash; because in a relocatable object a defined symbol's value is an <em>offset within its section</em>, not an address.</strong> &quot;Addend&quot; is <code>A</code>. And the offset column is where the bytes are, not what they contain. All three are things a reader must keep apart, and the next section is about exactly how they get confused.</p>

                <h3>Case two: ELF32 with REL &mdash; the addend is in the bytes</h3>
                <p>Same source, 32-bit target, <code>-fno-pic</code> so the encodings are the simple absolute ones. <code>demo_i386_nopic.o</code>'s <code>.text</code>, 0x40 bytes at file offset <code>0x40</code>:</p>
                <div class="hex-dump">
                    <pre>  00000040: 8b44 2404 01c0 0305 0000 0000 8b0d 0000
  00000050: 0000 01c8 83c0 03c3 0f1f 8400 0000 0000
  00000060: e9fc ffff ff66 662e 0f1f 8400 0000 0000
  00000070: a100 0000 000f be00 83c0 69c3
                  ^^
                  e9 = jmp rel32, opcode at text offset 0x20
                  fc ff ff ff = the addend, at text offset 0x21
</pre>
                </div>
                <p>And the relocation record for it &mdash; note there is <strong>no third field</strong>, because there is no such thing as an addend field in a <code>REL</code> record:</p>
                <div class="hex-dump">
                    <pre>  00000008  00000802  R_386_PC32   external_fn

  +0  r_offset  u32  = 0x00000021    &lt;- points AT the fc ff ff ff
  +4  r_info    u32  = 0x00000802    &lt;- type 2, symbol 8
                                       &lt;- 8 bytes total. No addend.
</pre>
                </div>
                <p><strong>There is the contrast, in two files produced from the same 30 lines on the same machine.</strong> x86-64 stores the <code>-4</code> in a 24-byte record and leaves the bytes zero; i386 stores the <code>-4</code> in the bytes and uses an 8-byte record with nowhere to put it. Everything else about the mechanism is identical, which is what makes it a clean experiment: <strong>the difference is the format's choice, and both are correct ELF.</strong></p>
                <p>Worth noting what the other two relocations in that file do. <code>addl $disp32, %eax</code> at text offset 6 has a <code>disp32</code> of <code>00 00 00 00</code> and an <code>R_386_32</code>, which is absolute and therefore needs no bias. <strong>Only the PC-relative one carries <code>-4</code>, and only because <code>P</code> is inside the instruction.</strong></p>

                <h3>Case three: COFF &mdash; the addend is nowhere, and the type supplies it</h3>
                <p>This is the case that surprises people, because COFF has no addend field <em>and</em> the bytes are zero. <code>demo_coff.o</code>'s <code>.text</code> at file offset <code>0x12c</code>:</p>
                <div class="hex-dump">
                    <pre>  0000012c: 01c9 030d 0000 0000 8b05 0000 0000 01c8
                     ^^^^
                     the four bytes the REL32 at offset 4 patches:
                     all zero, and the record has no addend field
</pre>
                </div>
                <p>So where is the <code>-4</code>? <strong>In the definition of <code>IMAGE_REL_AMD64_REL32</code>, which the PE/COFF specification defines as the 32-bit displacement from the byte <em>following</em> the relocation.</strong> The bias is a property of the relocation <em>type</em>, applied by the linker every time, for free, with nothing in the file to store it.</p>
                <p>This is verifiable, and the way to verify it is to link the object and look at what appears. <code>demo.c</code> compiled for <code>i386-pc-windows-msvc</code>, linked with <code>ld -m i386pe --oformat pei-i386</code> against a second object defining <code>external_fn</code>:</p>
                <div class="hex-dump">
                    <pre>  BEFORE, in the object:                AFTER, in the linked PE:
  00401020: e9 00 00 00 00                00401020: e9 1b 00 00 00

  the field was zero.                 the field is now 0x1b = 27.

  where did 27 come from?
    S   = 0x401040   (_external_fn)
    P   = 0x401021   (the field's own address)
    the bias, from REL32's definition, is 4 (to the byte AFTER)
    0x401040 - (0x401021 + 4) = 0x401040 - 0x401025 = 0x1b
</pre>
                </div>
                <p><strong>The <code>-4</code> is nowhere in the input file, and the output has it.</strong> That is the proof, and it settles a question the ELF cases cannot: in <code>RELA</code> the addend is data, and in COFF it is code. A tool that reconstructs an object file from a linked image has to re-derive COFF's addend from the type, and cannot get ELF's without having kept the records.</p>

                <h3>Case four: Mach-O &mdash; the same situation, honestly stated</h3>
                <p><code>demo_macho.o</code>'s <code>__text</code> at file offset <code>0x2c0</code>, and all four relocation offsets are <strong>zero</strong>:</p>
                <div class="hex-dump">
                    <pre>  000002c0: 5548 89e5 01ff 033d 0000 0000 8b05 0000
  000002d0: 0000 01f8 83c0 035d c30f 1f80 0000 0000
  000002e0: 5548 89e5 5de9 0000 0000 660f 1f44 0000
  000002f0: 5548 89e5 488b 0500 0000 0fbe 0083 c000
  00000300: 695d c3

  offsets 0x08, 0x0e, 0x26, 0x37 ->  00 00 00 00  every one
  the records have no addend field, and r_pcrel = 1
</pre>
                </div>
                <p>So Mach-O is in the same position as COFF: no addend field, zero bytes, and the correction must come from the relocation type. <strong>What I can and cannot claim here matters, so it is worth being exact.</strong> The Apple documentation defines <code>X86_64_RELOC_SIGNED</code> and <code>X86_64_RELOC_BRANCH</code> as a displacement measured from the end of the instruction, which is the same convention <code>REL32</code> uses &mdash; so the bias is applied by <code>ld64</code> from the type. <strong>I have not measured that, because there is no Mach-O linker on this machine and binutils refuses the format.</strong> The ELF and COFF claims above are measured; this one is documented, and the honest thing is to say which is which rather than present all three as equally established.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Three things get printed in a relocation listing, and on this course's specimens all three look like &quot;the value&quot;. Only one of them is. Here are all three, for the same relocation, from three tools:</p>
                <div class="hex-dump">
                    <pre>  THE RELOCATION: .text + 4, R_X86_64_PC32, against global_counter

  tool              what it prints            what that actually is
  ----------------  ------------------------  ---------------------------
  readelf -rW       Symbol's Value 0000...0    S: the symbol's st_value,
                    Name + Addend             0 because it is UNDEFINED

  llvm-objdump -r   global_counter-0x4         A: the addend, concatenated
                                              onto the name for brevity

  xxd on .text      00 00 00 00               the field, currently ZERO

  and the record:
  xxd on .rela      ... fcff ffff ffff ffff    A: the addend, for real,
                                              as a signed i64
</pre>
                </div>
                <p><strong>Three different numbers, one relocation, and the concatenation is the trap.</strong> <code>global_counter-0x4</code> is not a symbol whose name contains a minus sign; it is a name and a value with no separator, because a disassembler's column is narrow. A tool that parses that column as a name gets a symbol called <code>global_counter-0x4</code>, fails to resolve it, and reports an undefined reference to a symbol that does not exist.</p>
                <p>The same three-way confusion has a nastier variant, and it is the one that costs people an afternoon. Consider a relocation whose symbol is <em>defined</em>:</p>
                <div class="hex-dump">
                    <pre>  THE RELOCATION: .rela.data + 8, R_X86_64_64, against .rodata.str1.1

  readelf:  0000000000000000 .rodata.str1.1 + 0

  Here Symbol's Value is 0 AND the addend is 0.  Two different
  zeros that mean different things:

    S = 0   the section symbol's st_value, an offset within
              the section -- correct, and not an address
    A = 0   the addend

  A reader that collapses "S + A" into one number and reports
  it as an address will print 0 for the address of a string
  literal.  In a relocatable object that is not wrong -- there
  are no addresses -- but it is not an answer either, and in
  a linked image the same computation must have picked up the
  section's base address from somewhere.
</pre>
                </div>
                <p>And there is a third trap in the same area, which the <a href="/courses/obj/lessons/obj-bss-common">COMMON concept</a> found and which belongs here because it is the same confusion wearing a different hat. <strong>A <code>SHN_COMMON</code> symbol's <code>st_value</code> is an alignment, not a value.</strong> So <code>S</code> is not an address, not an offset, and not a size &mdash; it is a constraint on where the linker may put the object. <strong>Which of the three things <code>S</code> means is decided by <code>st_shndx</code>, so the meaning of <code>st_value</code> is a three-level dependency: read the index, and only then know what the value is.</strong> A relocation against a COMMON symbol is the one case where the arithmetic <code>S + A - P</code> has to be deferred until the linker has allocated storage, and no field in the record tells you that &mdash; you have to look the symbol up.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ cd courses/obj/assets/samples
$ xxd -s 0x40  -l 8  demo_elf.o        # the field: zero
$ xxd -s 0x250 -l 8  demo_elf.o        # the addend: fffffffffffffffc
$ xxd -s 0x60  -l 6  demo_i386_nopic.o  # the field: fcffffff  &lt;- the -4</code></pre>
                <ul>
                    <li><strong>Confirm the whole claim in eight commands.</strong> Show that <code>demo_elf.o</code>'s <code>.text+4</code> is <code>00 00 00 00</code> while its <code>r_addend</code> is <code>fc ff ff ff ff ff ff ff</code>, and that <code>demo_i386_nopic.o</code>'s <code>.text+0x21</code> is <code>fc ff ff ff</code> with no addend field anywhere in its 8-byte record. <strong>Same source, same machine, two answers &mdash; and the only variable is whether the format's record type is REL or RELA.</strong></li>
                    <li><strong>Work out the size cost and check it against the files.</strong> An <code>Elf64_Rela</code> is 24 bytes and an <code>Elf64_Rel</code> is 16. Count the relocation records in <code>demo_elf.o</code> and in <code>demo_i386_nopic.o</code> and compute what the records alone cost in each. <strong>Then notice that the explicit form also makes the section smaller</strong>, because the bytes are zero rather than a pre-filled value &mdash; so the saving is not the whole story either.</li>
                    <li><strong>Find a relocation whose addend is NOT -4.</strong> Write <code>int *p = &amp;arr[3];</code> with <code>int arr[8];</code> and compile it for both targets. <strong>The x86-64 record will carry <code>A = 12</code>; the i386 file will have <code>0c 00 00 00</code> in the bytes at the field.</strong> Then find a PC-relative relocation in the same file and confirm it is still <code>-4</code>, which shows the two reasons for an addend coexisting in one file.</li>
                    <li><strong>Prove the COFF claim by linking, which is the only way to see a value the input never contained.</strong> <code>clang -target i386-pc-windows-msvc -O1 -c demo.c</code>, then <code>ld -m i386pe --oformat pei-i386 -o out.exe a.obj b.obj</code> against an object defining <code>external_fn</code>, then <code>llvm-objdump-21 -d out.exe</code>. <strong>Write down the four numbers &mdash; <code>S</code>, <code>P</code>, the bias, the result &mdash; and confirm the result appears in the output although nothing in either input file contained it.</strong> This is the single most convincing demonstration in the module.</li>
                    <li><strong>Establish the Mach-O case yourself, or establish that you cannot.</strong> There is no Mach-O linker on this machine and binutils refuses the format, so the claim rests on Apple's documentation rather than on measurement. <strong>Say so in your own notes</strong>, and then work out what a tool would have to do to verify it: it needs an object, a Mach-O linker, and a way to read the result &mdash; three things, which is a fair measure of how much easier ELF is to reason about.</li>
                    <li><strong>Look for the <code>-0x4</code> parsing trap in the wild.</strong> Run <code>llvm-objdump-21 -r</code> and <code>readelf -rW</code> over several objects in this course's sample directory, and write the parser for each that correctly separates name from addend. <strong>Then try the naive one &mdash; take the last whitespace-separated field as the symbol name &mdash; and count how many objects it breaks on.</strong> Every relocation with a nonzero addend breaks it, which on real code is most of them.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you are given a COFF object whose <code>.text</code> has a <code>00 00 00 00</code> at the offset of an <code>IMAGE_REL_AMD64_REL32</code> record, and that record has three fields &mdash; offset, symbol index, and type &mdash; and no addend. After a successful link the four bytes hold a non-zero displacement. The input file contained no addend and the output has one. Where did the -4 that made the arithmetic come out right come from, and what does that tell you about what a tool can and cannot recover from which format?</p>
                <div class="quiz" id="quiz-obj-addends-1">
                    <button class="quiz-option" data-correct="true" data-explain="The -4 comes from the specification of IMAGE_REL_AMD64_REL32 itself, which defines the value as the displacement from the byte following the relocated field rather than from the field's own address. The linker applies it as part of computing the relocation, so the constant is in the linker's code and never in the file. That makes the addend data in one format and code in another, and the recoverability asymmetry follows directly. An ELF RELA object records its addend as a field, so a tool holding the object can read the bias off the disk and reconstruct an equivalent object byte for byte. A COFF object does not, so no tool can recover it from the file: the only way to learn the bias is to know the relocation type's definition and apply it. The concrete demonstration is the measurement in this course -- linking the i386-pc-windows-msvc build and finding e9 1b 00 00 00 where the object had e9 00 00 00 00, where 0x1b is exactly 0x401040 minus 0x401025, and the 0x401025 is the field address plus the 4-byte bias that no input file mentioned. This is also why the format comparison is not a tie. ELF's record is bigger and COFF's is smaller, and the sizes are honest about the difference in what each format makes recoverable: ELF spends bytes to keep the constant on disk, COFF spends nothing and keeps it in the reader." onclick="checkQuiz('obj-addends-1', this)">From the specification of the relocation type: <code>IMAGE_REL_AMD64_REL32</code> is defined as a displacement from the byte <em>after</em> the field, so the linker applies the 4-byte bias itself and the constant never exists in the file. That makes the addend <strong>code</strong> in COFF and <strong>data</strong> in an ELF <code>RELA</code> record &mdash; so a tool holding the COFF object can never recover the bias from it, while a tool holding the ELF object can read it off the disk and rebuild the object byte for byte</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion is right and the mechanism is a real thing, but it is not the mechanism in this case, and the difference matters because it changes who is responsible for the correction. A pre-filled field under the implicit scheme would mean the four bytes already contained a partial value -- the symbol's section-relative offset plus the addend -- and the linker would overwrite it. That is exactly what happens in an ELF REL object, and it is why i386's .text has fc ff ff ff sitting in the bytes at the field while its 8-byte record has no addend field at all. But in this COFF object the bytes are 00 00 00 00, which is not a partial value, it is nothing. Nothing was pre-filled, so there is nothing to be stale and nothing to be corrected: the linker is not fixing up a wrong value, it is supplying a value that was never there. The distinction is worth keeping precisely because it sharpens the earlier contrast. Under REL the section bytes are wrong until the link, which is a real hazard when sections are reordered. Under RELA the bytes are zero, which is never wrong. Here in COFF the bytes are also zero, and the reason is different -- not that the format chose to keep the addend elsewhere, but that the format has no addend concept at the record level and encodes the bias in the relocation type's meaning instead. So the correction is applied by the linker unconditionally, from its own tables, on every REL32 in every file, whether or not the object ever had a value to correct. That is why nothing in the input contained it." onclick="checkQuiz('obj-addends-1', this)">From the section bytes: the producer pre-filled the field with the symbol's section-relative offset plus the addend, and the linker overwrote it with the real value. That is why the zero you see is a <em>stale</em> value rather than an absent one, and it is the same implicit-addend scheme an ELF <code>REL</code> object uses</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a tool that converts object files: it reads an ELF object, applies relocations itself, and writes a new object file that should be byte-comparable to the input where nothing needed changing. It works on ELF64-RELA input. On ELF32-REL input it produces a file that links and runs correctly, but which is not byte-comparable &mdash; the <code>.text</code> section differs, and the relocation sections differ in size. On COFF input it produces a file that links and runs correctly and is not byte-comparable either. Diagnose both, and say which of the three differences a tool could in principle eliminate.</p>
                <div class="quiz" id="quiz-obj-addends-2">
                    <button class="quiz-option" data-correct="true" data-explain="Both differences are the same difference seen from two sides, and naming it precisely is the whole answer. The REL case is a genuine information loss in one direction and a redundancy in the other. The input's section bytes carried symbol-offset-plus-addend, which the linker discards; your output's bytes carry whatever you wrote, which is presumably zero or your own recomputation. Both are correct for linking, and they differ, so byte-comparability fails. But the relocation section size difference is a different animal entirely and it is not a loss of information at all -- an Elf32_Rel is 8 bytes and an Elf32_Rela is 12, and you emitted REAs because your writer only knows how to write the explicit form. The ELF32 input's bias was in the bytes; your output's bias is in the record; both say the same thing about the instruction. So of the three, only the COFF difference is truly unrecoverable, and it is unrecoverable for the reason the retrieval question established: the bias was never in the file, it lives in the definition of REL32, so a tool cannot read it off the disk and put it back. Which means a round-trippable COFF writer must re-derive the bias from the relocation type for every record, and the test of whether it did so correctly is that the linked output is identical -- not that the object is identical, because the object cannot be. The practical advice that falls out is worth stating plainly: byte-comparability is only a meaningful test for a format that keeps its constants on disk, and ELF64-RELA is the case where it is available. Everywhere else, compare linked behaviour." onclick="checkQuiz('obj-addends-2', this)">Both are the same cause seen from two sides: the addend is not where your writer puts it. The REL input has it in the section bytes and no field for it, so your output either drops it or re-derives it and the bytes differ; the record-size difference is simply that an <code>Elf32_Rel</code> is 8 bytes and an <code>Elf32_Rela</code> is 12, so you emitted a different record type. <strong>Only the COFF case is genuinely unrecoverable</strong> &mdash; its bias was never in the file at all, so no tool can read it off the disk and restore it, and a byte-comparable COFF writer is impossible by construction. Byte-comparability is a meaningful test only for the format that keeps its constants in the file</button>
                    <button class="quiz-option" data-correct="false" data-explain="This answer names the right format as the unrecoverable one but misdiagnoses why, and the reason it misdiagnoses it is that it treats all three inputs as using the same scheme. They do not. The ELF32-REL case is the opposite of unrecoverable: there the addend is in the section bytes, fully present on disk, and your tool simply chose not to read it from there. That is recoverable in the strongest possible sense -- the information is sitting in the input, and a writer that put it back would produce a byte-identical file. The RELA case is recoverable too, with the addend in the record, again present on disk. COFF is the one that is not, and not because the bias is stored in an inconvenient place but because it is not stored anywhere. Nothing in a COFF object records the 4-byte instruction-length bias; it is a property of what IMAGE_REL_AMD64_REL32 means, applied by the linker from its own tables. A tool cannot copy a constant that was never written down. So the diagnosis has the diagnosis right and the reasoning exactly inverted, which is the more dangerous kind of wrong because the conclusion sounds right. The other half -- that the size difference is a record-type difference rather than an information loss -- is correct and worth keeping, since 8 versus 12 bytes for Elf32_Rel versus Elf32_Rela is precisely a statement about where the format chose to keep the addend." onclick="checkQuiz('obj-addends-2', this)">The ELF32-REL case is unrecoverable, because the implicit scheme loses the addend once the linker overwrites the section bytes, so the information cannot be recovered from the file. The COFF and ELF64-RELA cases are fine, since both record the addend explicitly and can be reconstructed exactly</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: before you can decide whether a format is round-trippable, find out whether its constants are <em>on disk</em>. That single question separates the three cases, and it is the difference between a format you can rewrite and one you can only re-derive.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the second half of <a href="/courses/obj/lessons/obj-relocations">the fixup record</a>, and the two are one idea seen at two magnifications. That concept asked what a record contains; this one asks where the constant goes, and the answer is that the format's choice about the record's <em>size</em> is really a choice about where the arithmetic's constant lives. <strong>24 bytes versus 8 bytes is not a compactness decision, it is a decision about whether the section bytes are allowed to be wrong before the link.</strong></p>
                <p>The bias connects to <a href="/courses/obj/lessons/obj-the-hole">A Hole and a Record</a> and to the course's very first measurement. The finding there was that the four relocation offsets land on the trailing <code>disp32</code> of instructions of <em>three different lengths</em> &mdash; a 6-byte, a 6-byte, a 5-byte and a 7-byte encoding &mdash; and every one of them has the same <code>-4</code>. <strong>That sameness is the bias being a property of the encoding rather than of the reference.</strong> The moment an architecture has an instruction whose displacement field is not four bytes before the end, the bias changes, and on AArch64 it is not even a single number: the <code>ADRP</code>/<code>LO12</code> pair that <a href="/courses/obj/lessons/obj-reloc-tables">the relocation table</a> concept describes carries a <em>21-bit</em> page delta split across bits 30:29 and 23:5. <a href="/courses/obj/lessons/obj-arch-table">The encodings concept</a> takes that apart, and it is where this concept's arithmetic stops being simple.</p>
                <p>The COMMON connection is the sharpest one, and it is a three-level dependency worth restating because it is easy to miss. <strong>A <code>SHN_COMMON</code> symbol's <code>st_value</code> is an alignment.</strong> So in the formula <code>S + A - P</code>, the <code>S</code> term is not a position at all &mdash; and which of the three meanings it has is decided by <code>st_shndx</code>, whose reserved values are the special case. <a href="/courses/obj/lessons/obj-bss-common">The COMMON concept</a> measured all five builds; this concept names why the result matters: <strong>a relocation against a COMMON symbol cannot be computed at object-write time, because the storage does not exist yet.</strong> It is the same family of problem as an undefined weak, which <a href="/courses/obj/lessons/obj-weak-undef">Module 4</a> handles, and both are cases where the format must record a <em>promise</em> rather than a value.</p>
                <p>On the portability side there is a real consequence that connects to <a href="/courses/pe">the PE course</a>. <strong>A format that keeps its constants on disk is auditable; a format that keeps them in its own specification is not.</strong> That sounds like a distinction without a difference until you try to write a validator, or a tool that must transform an object without linking it &mdash; an obfuscator, a coverage-instrumentation pass, a binary patcher. For ELF-RELA the answer is on the disk. For COFF it has to be re-derived from the type, every time, and a validator that forgets the bias for one type will report a well-formed file as corrupt. <strong>That is the practical difference between storing a constant and defining it, and it is the difference between a property you can read and a property you have to know.</strong></p>
                <p>Finally, the three-way confusion in the listing output connects to <a href="/courses/obj/lessons/obj-symbols">Symbol Tables, Compared</a>, because all three of those columns come from two different tables that the listing interleaves. <strong>A relocation listing is a join of the relocation table and the symbol table, and the join is where the confusion lives</strong> &mdash; a tool that displays them side by side without separators has made the reader do a disambiguation the format never asked for. Next: the type vocabulary those <code>S + A - P</code> formulas are drawn from.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-relocations">Previous: The Fixup Record</a></span>
                <span><a href="/courses/obj/lessons/obj-reloc-tables">Next: The Object Relocation Sets</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
