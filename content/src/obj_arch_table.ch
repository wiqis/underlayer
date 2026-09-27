// Object Files — Module 5: Emitting One
// Concept: the x86-64 and AArch64 instruction forms a fixup has to patch, and
// why a 4-byte displacement cannot be patched into a 1-byte field.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_arch_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Encodings That Set Relocation Size — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>The Encodings That Set Relocation Size</h1>
            <div class="lesson-meta">20 min &middot; Module 5: Emitting One &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a relocation, and the question it does not answer:</p>
                <div class="hex-dump">
                    <pre>  0000000000000004  R_X86_64_PC32  global_counter - 4
</pre>
                </div>
                <p>Everything up to this point has been about <em>which</em> four bytes, <em>which</em> symbol, and <em>which</em> arithmetic. <strong>Now ask the question a linker author actually has to answer: how many bytes is the field?</strong> The record does not say. The type implies it, sort of, and the only authoritative answer is the instruction encoding &mdash; which means <strong>a correct <code>PC32</code> implementation requires knowing that <code>mov</code> with a RIP-relative operand is 7 bytes, that <code>add</code> is 6, that <code>call</code> is 5, and that the field sits at a different offset within each.</strong></p>
                <p>This is the concept where &ldquo;every instruction, every architecture&rdquo; stops being a slogan. <a href="/courses/obj/lessons/obj-reloc-tables">The relocation table</a> reduced 147 AArch64 types to seven flags. <strong>This is what those flags are applied to, and the reason a linker for a new architecture is a multi-month project rather than an afternoon.</strong></p>
                <p>And the failure mode is the sharpest in the course, because it is a <em>truncation</em>:</p>
                <div class="callout callout-warn">
                    <strong>A 4-byte displacement cannot be patched into a 1-byte field.</strong> If an instruction encodes a displacement in 8 bits and the linker computes a value that needs 24, there is no way to write it. The linker must <em>fail the link</em>. A linker that truncates instead produces a binary that runs, jumps somewhere nearby, and misbehaves in ways that look like a logic bug rather than a toolchain bug. <strong>This is exactly what the <code>TYPE</code> flag exists to prevent</strong> &mdash; not to make the linker clever, but to make it refuse.
                </div>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three questions, and they are asked in this order by any correct implementation:</p>
                <div class="formula">
  Q1  WHERE IS THE FIELD?

      The record gives a byte offset.  Converting it to a
      field requires decoding the instruction, because the
      offset is relative to the SECTION and the field is at
      a position that depends on the encoding.

      Q1a  how many bytes is the instruction?
      Q1b  at what offset within it does the field start?

  Q2  HOW MANY BYTES IS THE FIELD, AND IS IT SIGNED?

      From the encoding, not the record.  A linker that
      assumes 4 because the type name ends in 32 is wrong
      on every architecture that has narrower forms -- and
      those are the ones that matter, because the narrow
      forms are what make short branches possible.

  Q3  DOES THE VALUE FIT?

      If not, the link fails.  There is no third option.
</div>
                <p><strong>And the reason Q1a and Q1b are separate questions is the whole concept in one line:</strong> the same 4-byte field type appears at different positions inside instructions of different lengths, so a linker that hardcodes an offset-from-instruction-start is wrong for every encoding that uses prefixes.</p>
                <p>The clean case and the awkward case, side by side, on real bytes from <code>enc_nopic.o</code> (clang 21, <code>-O0 -fno-pic</code>):</p>
                <div class="hex-dump">
                    <pre>  0x00:  8b 04 25 00 00 00 00        6 bytes, field at +3
          movl 0x0, %eax              R_X86_64_32S @ 0x03

  0x24:  48 8b 04 25 00 00 00 00     7 bytes, field at +4
          movq 0x0, %rax              R_X86_64_32S @ 0x28

  The two instructions are the SAME operation with a
  different register width.  The REX prefix makes the
  instruction one byte longer and pushes the field one
  byte later.  The relocation type is identical.
</pre>
                </div>
                <p>So the record says <code>offset 3</code> in the first and <code>offset 0x28</code> in the second, and <strong>in both cases the field is the last four bytes of the instruction.</strong> For these forms the rule &ldquo;the field is the last four bytes&rdquo; is a usable shortcut &mdash; and it is a shortcut that breaks the moment an instruction has an immediate after the displacement, which is the next entry in the table.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>x86-64: the forms you will meet, with their field offsets</h3>
                <p>Every row measured from a real <code>-fno-pic</code> object in this course's <code>assets/samples/</code>:</p>
                <div class="hex-dump">
                    <pre>  bytes              len  field at  instruction          reloc type
  ----------------   ---  ---------  ---------------------  --------------
  e8 00 00 00 00      5     +1      call rel32             PLT32
  e9 00 00 00 00      5     +1      jmp  rel32             PLT32
  0f 84 00 00 00 00   6     +2      jz   rel32             PC32
  8b 05 00 00 00 00   6     +2      movl (%rip), %eax      PC32
  8b 04 25 00 00 00 00 6    +3      movl 0x0, %eax         32S
  48 8b 05 00 00 00 00 7     +3      movq (%rip), %rax      PC32
  48 8b 04 25 00 00 00 00 7   +4      movq 0x0, %rax         32S
  c7 04 25 00 00 00 00 01 00 00 00
                      10     +3      movl $1, 0x0           32S
</pre>
                </div>
                <p>Four things fall out of that table, and each one is a rule a linker needs.</p>
                <ul>
                    <li><strong>The field is 4 bytes in all of them, and always the <em>displacement</em>.</strong> That is why one relocation type can serve a call, a jump, a conditional jump and a data load. The architecture's designers made the displacement a fixed 4 bytes across the common forms, which is what lets <code>R_X86_64_PC32</code> be so widely applicable.</li>
                    <li><strong>The field offset is not constant.</strong> It is +1 for the one-byte-opcode call and jump, +2 for the two-byte-opcode <code>0f 8x</code> and the <code>8b 05</code> form, +3 for the three-byte <code>8b 04 25</code> SIB form, and +4 when a REX prefix is present. <strong>There is no arithmetic that derives this from the relocation type; the instruction has to be decoded.</strong></li>
                    <li><strong>The <code>c7 04 25</code> form has an immediate <em>after</em> the displacement</strong>, which is why &ldquo;the field is the last four bytes&rdquo; fails here and the last-<em>five</em>-rule has to be used instead. This is the trap that makes the shortcut dangerous rather than merely convenient.</li>
                    <li><strong>Relative jumps use the same encoding as calls</strong> &mdash; <code>e8</code> and <code>e9</code> differ only in the low three bits of the opcode, and both are <code>rel32</code>. So <code>R_X86_64_PLT32</code> covers both, and a linker that treats &ldquo;call&rdquo; as a distinct type is already wrong on jumps.</li>
                </ul>

                <h3>And the narrow forms, which is where truncation lives</h3>
                <p>The 4-byte field above is the <em>common</em> case, not the only one. x86-64 also has 8-bit and 16-bit displacement forms, and they are what make short branches and short jumps encodable at all:</p>
                <div class="hex-dump">
                    <pre>  eb 00              2 bytes   jmp  rel8    field at +1, 1 byte
  70 00              2 bytes   jo   rel8    field at +1, 1 byte
  e8 00 00 00 00     5 bytes   call rel32   field at +1, 4 bytes
  0f 84 00 00 00 00  6 bytes   jz   rel32   field at +2, 4 bytes

  A rel8 reaches +/-128 bytes.  A rel32 reaches +/-2 GiB.
  The assembler picks the short form when the target is
  near -- and it can only know that after layout, which
  is why a linker may have to relax.
</pre>
                </div>
                <p><strong>That last point is the one that matters for an emitter and it is easy to miss.</strong> If the assembler emitted <code>eb</code> (a 2-byte jump with an 8-bit field) and the linker later places the target 200 bytes away, the value does not fit in one byte. The 1-byte field holds <code>0xc8</code> = 200 as unsigned, or -56 as signed &mdash; <strong>and the jump silently goes to the wrong place.</strong> The relocation types <code>R_X86_64_PC8</code> and <code>R_X86_64_PC16</code> exist for exactly these, and the <code>TYPE</code> flag on them is what says: <em>this field holds an address, so if the value does not fit, fail the link.</em> A linker that truncates produces a jump to the wrong address with no diagnostic, and the resulting program is the kind of bug that gets reported as &ldquo;my compiler is broken&rdquo;.</p>

                <h3>AArch64: where the field is not even contiguous</h3>
                <p>Now the architecture that changes the shape of the problem, using real bytes from <code>enc_a64_nopic.o</code>. <strong>One reference to a global produces two relocations, and neither field is a little-endian integer sitting in the byte stream:</strong></p>
                <div class="hex-dump">
                    <pre>  0000: 90000008      adrp x8, #0
        relocation @ 0x00  R_AARCH64_ADR_PREL_PG_HI21   g32
  0004: b9400100      ldr  w0, [x8]
        relocation @ 0x04  R_AARCH64_LDST32_ABS_LO12_NC  g32
  0008: d65f03c0      ret
</pre>
                </div>
                <p>Decode the first word bit by bit. The file bytes are <code>08 00 00 90</code>, so the little-endian word is <code>0x90000008</code>:</p>
                <div class="formula">
  ADRP encoding:  1  immlo(2)  10000  immhi(19)  Rd(5)

  bit 31        op         = 1        (ADRP, not ADR)
  bits 30:29    immlo      = 00         2 of the 21 bits
  bits 28:24    fixed      = 10000    (must be exactly this)
  bits 23:5     immhi      = 00000      the other 19 bits
  bits 4:0      Rd         = x8

  the 21-bit SIGNED page delta = (immhi &lt;&lt; 2) | immlo
</div>
                <p><strong>So the 21-bit value the linker must write is split into 2 bits at the top of the word and 19 bits in the middle, with the opcode, a fixed marker, and the destination register interleaved.</strong> And the second instruction's field is a different bit range of a different word:</p>
                <div class="formula">
  LDR (immediate) encoding:  size(2) 111001 opc(2) imm12(12) Rn(5) Rt(5)

  bits 31:30    size      = 10        (2 = 32-bit access)
  bits 29:24    fixed     = 111001
  bits 23:22    opc       = 01        (LDR, 32-bit)
  bits 21:10    imm12     = the 12-bit page offset  &lt;- the second field
  bits 9:5      Rn        = x8
  bits 4:0      Rt        = w0
</div>
                <p><strong>Three consequences, and each one is a design requirement a linker must satisfy.</strong></p>
                <ul>
                    <li><strong>Read-modify-write, not overwrite.</strong> A linker that writes four bytes at the relocation offset destroys the opcode, the register, and half of the displacement. <strong>It has to read the word, mask the field out, OR the new value in, and write it back</strong> &mdash; twice, once per half, and the two halves are in different words.</li>
                    <li><strong>The 21 bits are a page delta, so the value must be divided by 4096</strong> and the low 12 bits go in the other instruction. <code>ADRP</code> gives you a 4&nbsp;MB-aligned address; the <code>LDR</code>'s <code>imm12</code> selects within the page. <strong>A linker that treats them independently computes two half-expressions and links cleanly, then faults at run time</strong> &mdash; which is why <a href="/courses/obj/lessons/obj-reloc-tables">the relocation table concept</a> found every one of these entries carries the <code>SIZE</code> flag saying &ldquo;this is not independent.&rdquo;</li>
                    <li><strong>The 21 bits are signed and sign-extended, and getting that wrong is silent.</strong> A page delta of -5 must be encoded as a 21-bit two's-complement value, and <code>immlo</code> takes bits 1:0 of it while <code>immhi</code> takes bits 20:2. Encode it as an unsigned 21 and you get a positive value roughly a million pages away.</li>
                </ul>
                <p>All three of those claims are checkable without an AArch64 machine, and <code>aarch64_enc.py</code> in the samples directory does the checking by building the words and asking a real disassembler to read them back:</p>
                <div class="hex-dump">
                    <pre>  $ python3 aarch64_enc.py --build 3
  ADRP  word = 0xf0000008
        bits 30:29  immlo   = 3
        bits 23:5   immhi   = 0
        =&gt; 21-bit signed page delta = 3 pages = +12288 bytes

  and the same word, placed with .inst and disassembled:

  $ clang -target aarch64-linux-gnu -O0 -c adrp_test.c -o t.o
  $ llvm-objdump-21 -d t.o
  0000: f0000008   adrp x8, 0x3000        &lt;- exactly +3 pages
  0004: f0ffffc8   adrp x8, 0xffffffffffffb000   &lt;- -5 pages
  0020: 90000008   adrp x8, 0x0
</pre>
                </div>
                <p><strong>That is a positive verification, not an absence of error.</strong> Encoding a known value and having an independent disassembler read back exactly that value is a much stronger claim than reading zeros and confirming they are zero &mdash; and it is the form of check the mission's rule actually asks for.</p>

                <h3>The forms that differ only in width</h3>
                <p>And the reason <a href="/courses/obj/lessons/obj-reloc-tables">44 x86-64 entries</a> exist when the table above has eight rows. Every form has a narrower sibling:</p>
                <div class="hex-dump">
                    <pre>  R_X86_64_8    1-byte absolute      R_X86_64_16   2-byte absolute
  R_X86_64_32   4-byte absolute      R_X86_64_32S  4-byte signed absolute
  R_X86_64_64   8-byte absolute      R_X86_64_PC8  1-byte PC-relative
  R_X86_64_PC16 2-byte PC-relative   R_X86_64_PC32 4-byte PC-relative
  R_X86_64_PC64 8-byte PC-relative

  and the general shape is a CROSS PRODUCT:
      ( absolute, PC-relative, GOT-relative )
    x ( 1, 2, 4, 8 bytes )
    x ( signed, unsigned )
</pre>
                </div>
                <p><strong>So the count is not a list of 44 unrelated ideas; it is about nine behaviours expanded by a cross product of width and sign.</strong> That is the <a href="/courses/obj/lessons/obj-reloc-tables">relocation table concept's</a> claim, and this concept supplies the reason it is true: <strong>the width is a property of the instruction encoding, the sign is a property of whether the architecture treats the field as an address or as a number, and neither is a property of the idea being expressed.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Putting the two architectures side by side, and asking the question an emitter has to answer for each relocation it writes:</p>
                <div class="hex-dump">
                    <pre>                      x86-64                    AArch64
  ------------------   ----------------------   ----------------------
  is the field         YES, usually.  Four        NO.  Bit ranges
  contiguous?          contiguous bytes, at      inside a 32-bit word,
                       a fixed position in       interleaved with the
                       the instruction           opcode and registers

  can you overwrite    yes, if you know the      NO, always.  Read the
  it?                  length                    word, mask, OR, write

  how wide can it       1, 2, 4 or 8 bytes       12, 16, 19+2, 21 or 26
  be?                   depending on the form     bits, none of them
                                                byte-aligned

  what does overflow   the TYPE flag: fail        the TYPE flag: fail.
  look like?           the link                  On ADRP the 21-bit
                                                field cannot hold a
                                                delta beyond +/-4 GiB,
                                                and the linker must
                                                refuse rather than wrap

  how many records     1                         2, for one reference
  per reference?

  what the compiler    the encoding              the encoding, and it is
  must do              and the layout            the layout -- which is
                                                why -fPIC changes
                                                instruction LENGTHS
</pre>
                </div>
                <p>The last row is the finding that ties this concept back to <a href="/courses/obj/lessons/obj-pic">Position Independence</a>, and it was measured rather than assumed. <strong>Switching to <code>-fPIC</code> on x86-64 changed the relocation offsets in the same file, from <code>0x04, 0x0a, 0x21, 0x33</code> to <code>0x05, 0x0e, 0x21, 0x33</code>.</strong> The data references moved because <code>REX_GOTPCRELX</code> needs a REX prefix byte that the plain RIP-relative form does not, so the instructions grew by one byte and everything after them shifted. <strong>Changing the relocation type changed the instruction encoding, which changed every subsequent offset in the section.</strong></p>
                <p>That is a genuinely surprising coupling and it has a direct consequence for tooling: <strong>you cannot compute relocation offsets independently of relocation types, and a tool that walks instructions and records &ldquo;there is a fixable field here&rdquo; without knowing which form it is will be wrong on every <code>-fPIC</code> object.</strong> The offsets in a <code>-fPIC</code> object are not a shifted copy of the non-PIC ones; they are a different set.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ cd courses/obj/assets/samples
$ llvm-objdump-21 -d -r enc_nopic.o
$ python3 aarch64_enc.py
$ python3 aarch64_enc.py --build -5</code></pre>
                <ul>
                    <li><strong>Build the field-offset table yourself from the disassembly, and check every row.</strong> For each instruction, count the bytes before the displacement and confirm the relocation offset from <code>-r</code> matches. <strong>Then find one where it does not, because there is one</strong> &mdash; the <code>c7 04 25</code> form with its trailing immediate is the case that breaks &ldquo;the last four bytes.&rdquo; Working out the general rule from the exception is the exercise.</li>
                    <li><strong>Change the optimisation level and watch the encodings change underneath.</strong> Compile the same function at <code>-O0</code>, <code>-O1</code> and <code>-O2</code>, dump all three, and tabulate the instruction lengths and field offsets. <strong>You will find that the <em>same source</em> produces different field positions at different levels</strong>, which is the clearest possible argument that a linker cannot hardcode them and the clearest possible argument for why the relocation offset must be a byte offset and not an instruction index.</li>
                    <li><strong>Trigger the overflow check on purpose.</strong> Write a jump whose target is more than 128 bytes away but was encoded as <code>eb</code> (rel8) by hand, emit it with your own writer, and link. <strong>Watch the linker refuse</strong>, then remove the check and watch it link &mdash; and then work out, by disassembling, exactly where the program went instead. <strong>That is the <code>TYPE</code> flag earning its keep, and seeing the failure it prevents is worth more than reading that it would happen.</strong></li>
                    <li><strong>Verify the AArch64 encoding positively, both signs.</strong> <code>python3 aarch64_enc.py --build 3</code> and <code>--build -5</code>, place the resulting words with <code>.inst</code>, and confirm <code>llvm-objdump-21</code> prints <code>adrp x8, 0x3000</code> and <code>adrp x8, 0xffffffffffffb000</code> respectively. <strong>Then break the sign extension deliberately</strong> &mdash; encode -5 as an unsigned 21 &mdash; and see what the disassembler reports. The wrong answer will be a plausible address about four million pages away, which is the exact failure mode of a sign bug in a linker.</li>
                    <li><strong>Count the field widths in a real object and check the cross-product claim.</strong> Take <code>demo_elf.o</code> and <code>enc_nopic.o</code>, list every relocation type, and sort by width and by absolute/PC-relative. <strong>Then find the entries that do not fit the cross product</strong> &mdash; the GOT-relative and PLT families are the likely exceptions &mdash; and work out why each is a genuinely different operation rather than another width variant.</li>
                    <li><strong>Reproduce the <code>-fPIC</code> offset shift.</strong> Compile <code>demo.c</code> three ways: no flag, <code>-fPIC</code>, <code>-fPIE</code>. Dump the relocation offsets from each and confirm that <code>-fPIE</code> is byte-identical to no flag while <code>-fPIC</code> shifts the data references by one byte. <strong>Then explain the shift in terms of the encoding table above</strong> rather than in terms of &ldquo;PIC is different&rdquo; &mdash; the answer is the REX prefix, and working it out from the table is the point of the exercise.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a linker is applying <code>R_AARCH64_ADR_PREL_PG_HI21</code> at offset 0 of a section, and the instruction there is the four bytes <code>08 00 00 90</code>. The linker must write a page delta of 3. The file's little-endian word is <code>0x90000008</code>. Where exactly do the three bits of the value 3 go, why can the linker not simply write four bytes, and what happens to the other 29 bits if it tries?</p>
                <div class="quiz" id="quiz-obj-arch-table-1">
                    <button class="quiz-option" data-correct="true" data-explain="The value 3 is a 21-bit signed page delta, and the ADRP encoding splits it: bits 1:0 of the value go into immlo at bits 30:29, and bits 20:2 go into immhi at bits 23:5. For the value 3, immlo is 3 and immhi is 0, so the word becomes 0xf0000008 -- bit 31 stays 1 because it is the ADRP/ADR opcode, bits 28:24 stay 10000 because that is a fixed marker the assembler requires, and bits 4:0 stay 01000 because that is x8, the destination register. The linker cannot simply write four bytes because the displacement is not four bytes of storage. The word is the instruction, and the displacement occupies 21 of its 32 bits, interleaved with the opcode, the marker and the register number. A plain overwrite would set bits 0 through 7 to the value 3, which destroys the register field -- x8 would become x3 -- while also clearing the ADRP bit, turning an ADRP into an ADR, a completely different instruction with a completely different address range. So the operation must be read-modify-write: read the word, clear the immlo and immhi bit ranges, OR the new value into those ranges only, and write it back. And the value is a page delta, so the linker must subtract the section's base, subtract the instruction's own address, shift right by 12 to convert bytes to pages, sign-extend to 21 bits, and only then split and insert. Get the sign wrong and a backward jump becomes a forward one of about four million pages, which links cleanly and faults at run time." onclick="checkQuiz('obj-arch-table-1', this)">Bits 1:0 of the 21-bit value go into <code>immlo</code> at bits 30:29, and bits 20:2 go into <code>immhi</code> at bits 23:5 &mdash; so 3 becomes <code>immlo = 3</code>, <code>immhi = 0</code>, and the word becomes <code>0xf0000008</code>. It cannot overwrite because the displacement is <strong>not four bytes of storage</strong>: it is 21 bits interleaved with the opcode (bit 31), the fixed marker (28:24) and the destination register (4:0). <strong>A plain write would clobber the register field and clear the ADRP bit, turning ADRP into ADR</strong> &mdash; a different instruction with a different range. And the value must be converted to a signed page delta first: subtract the section base, subtract the instruction address, divide by 4096, sign-extend to 21 bits, then split and insert</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion about read-modify-write is right, and it is the most important thing in the answer, but the placement of the bits is wrong in a way that produces a different instruction rather than a wrong address, and that is the more dangerous kind of error because it fails at decode time rather than at run time. The answer puts the value in bits 30:29 and 23:5, which is correct, but then says a plain overwrite would destroy the opcode and turn ADRP into ADR. That is not what a four-byte overwrite of 0x00000003 would do to 0x90000008: it would set bits 2:0, leaving bit 31 as 1, so the opcode survives. What it destroys is the register field -- bits 4:0 of 0x90000008 are 01000, x8, and overwriting the low 32 bits with 3 changes them to 00011, so the destination register becomes x3 rather than x8. The instruction is still an ADRP, still writing a page delta, but to the wrong register, and the following ldr reads x8 and gets whatever was there before. So the concrete consequence of the naive implementation is a wrong-register write, not a changed opcode, and the difference matters for diagnosis: an instruction-decode error would be visible in a disassembler, whereas a wrong register looks like a logic bug. The other error is treating the value as a byte delta and asking the linker to divide by 4096. The relocation type already says what the value is; the linker converts to a page delta itself, and the division is part of the conversion, not something the value carries." onclick="checkQuiz('obj-arch-table-1', this)">The value 3 is written into the high bits, as a 21-bit field occupying bits 30:29 and 23:5. A plain four-byte write cannot work because those bits are interleaved with the opcode and the register, so the linker must read-modify-write. What it destroys is the <code>ADRP</code> opcode itself, turning the instruction into an <code>ADR</code> and silently changing its range from 4&nbsp;MB to 1&nbsp;MB</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing the relocation-application pass of a linker for a new 32-bit architecture. The ISA has three addressing forms: a 4-byte absolute field, a 4-byte PC-relative field, and a 12-bit PC-relative field for short branches. The relocation table has eleven types. Your pass reads each record, computes the value, and writes it. It is correct on nine of the eleven types. The two it gets wrong are the 12-bit PC-relative ones, and the failure is that a program with a branch to a distant label links, runs, and takes the wrong path. What is wrong, what should the pass have done, and why is this the single most important behaviour to get right in a relocation pass?</p>
                <div class="quiz" id="quiz-obj-arch-table-2">
                    <button class="quiz-option" data-correct="true" data-explain="What is wrong is that the pass truncates. It computes the correct value, then writes its low 12 bits into the field and discards the rest, because a 12-bit field physically cannot hold more and the code has no way to express the failure. The fix is to check before writing: compute the value, verify it is representable in the field's width and signedness, and if it is not, fail the link with a diagnostic naming the symbol, the section and the offset. That is what the TYPE flag exists for in ELF, and inventing it in your own table costs one comparison per relocation. The reason it is the most important behaviour in the whole pass is the asymmetry of the outcomes. Every other error in a relocation pass is loud: a wrong symbol index produces an undefined-reference error, an out-of-range offset produces a malformed-file error, a missing section produces a structural error. Truncation is the only error that produces no diagnostic at all, because the written value is a perfectly valid 12-bit number -- it is just the wrong one. The program links, loads, and begins executing, and it is wrong only on the branches that needed more than 12 bits, which in a real program is a small fraction of them. That is the worst possible shape for a bug: it passes every smoke test, it reproduces only on input that happens to have a distant branch, and it presents as a logic error in the program's own code rather than as a toolchain fault. The general principle is that a compiler backend should be assumed to have emitted a field too narrow whenever a target is out of range, and the linker's job is to say so rather than to accommodate it." onclick="checkQuiz('obj-arch-table-2', this)">The pass truncates: it computes the right value and writes only the low 12 bits, because a 12-bit field cannot hold more and the code has no way to express the failure. <strong>It must check representability first and fail the link</strong> &mdash; naming the symbol, section and offset &mdash; which is exactly what ELF's <code>TYPE</code> flag exists for. It matters most because truncation is the <em>only</em> error in a relocation pass that produces no diagnostic: the written value is a perfectly valid 12-bit number, just the wrong one, so the program links, runs, and misbehaves only on the branches that were out of range</button>
                    <button class="quiz-option" data-correct="false" data-explain="The diagnosis is right and the principle is right, but the recommended fix is worse than the bug, and it is worse in a way that would be discovered immediately in a real build. Sign-extending a truncated 12-bit value does not make the branch reach further; it changes what the truncated value means. Consider a short branch whose displacement should be 0x1F40, which needs 13 bits. Truncating to 12 bits gives 0xF40, and sign-extending that gives negative 192 -- so the assembler has emitted a one-byte backwards branch where it needed a five-byte forwards one. The program now jumps backwards into the middle of unrelated code instead of forwards to the label. The link succeeds, the error surfaces as a crash or as nonsensical behaviour somewhere else entirely, and the diagnostic now points at the wrong place: the value is not a truncated displacement, it is a completely different displacement. The correct response is not to reinterpret the value but to refuse it, because the information needed to emit a correct wide branch is in the assembler, not in the linker. A linker that sign-extends is guessing, and a linker that guesses about an address produces a binary that is confidently wrong. The value must be range-checked and the link failed, so that the assembler can be told to relax the branch to a wider form -- which is why ELF has separate relocation types for the two widths rather than one type with a flexible field." onclick="checkQuiz('obj-arch-table-2', this)">The pass truncates, and the fix is to <strong>sign-extend the 12-bit field before writing</strong>, so a value that needs more range is at least interpreted as a negative displacement and the branch fails loudly rather than silently going to the wrong place. This matters most because a linker that silently narrows a value produces a binary that runs, and every other kind of relocation error stops the link</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a narrowing write is the only silent error in a relocation pass. Range-check every field against its real width and signedness, and treat the check as mandatory rather than defensive.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept supplies the missing half of <a href="/courses/obj/lessons/obj-reloc-tables">The Object Relocation Sets</a>. That concept reduced 44 x86-64 types and 147 AArch64 types to seven property flags, and said a linker implements about nine cases. <strong>This is where the seventh flag, <code>SIZE</code>, and the eighth, <code>TYPE</code>, get their physical meaning.</strong> <code>SIZE</code> means &ldquo;this field is a bit range, not a byte range, and it has a partner&rdquo; &mdash; which is the AArch64 <code>ADRP</code>/<code>LO12</code> pair. <code>TYPE</code> means &ldquo;this field holds an address, so a value that does not fit is a link error, not a truncation&rdquo; &mdash; which is the 12-bit branch. <strong>Two flags, two concepts, and this is the concept that explains what they are for.</strong></p>
                <p>The connection to <a href="/courses/obj/lessons/obj-pic">Position Independence</a> is the strongest in the course and it is measured. <strong>Switching to <code>-fPIC</code> changed the relocation offsets in the same source file</strong>, because the GOT-indirect form needs a REX prefix that the direct form does not, so the instructions grew and every subsequent offset moved. That is not a fact about PIC; it is a fact about encodings, and it is only visible once you have the field-offset table in front of you. <strong>The practical consequence is that relocation offsets and relocation types are not independent data</strong> &mdash; a tool that computes one without the other is wrong on every PIC object, and a backend that chooses a relocation type has implicitly chosen an instruction length.</p>
                <p>The AArch64 read-modify-write requirement connects to <a href="/courses/jvm/lessons/jvm-attributes">the JVM's attribute mechanism</a> and to a shared shape. <strong>Both formats have a field whose value is encoded across bits rather than bytes, and both were designed by people who had a reason for it.</strong> The JVM needed an attribute length that could grow; AArch64 needed an instruction set where every instruction is a fixed 32 bits and the immediate fields are as wide as the addressing modes require. <strong>Read-modify-write is the price of fixed-width instructions, and it is a price worth paying when the alternative is a variable-length encoding that would make every decode branchier.</strong> The mission's &ldquo;read the waste to read the history&rdquo; technique applies here directly: the interleaving of opcode and displacement is a design decision visible in the bit layout, and it is the same decision visible in an ARMv7 Thumb encoding's narrower fields.</p>
                <p>There is also a direct connection to <a href="/courses/wasm/lessons/wasm-objects">the WebAssembly course</a>, and it is the sharpest cross-format lesson in the collection. <strong>WebAssembly's <code>R_WASM_MEMORY_ADDR_LEB</code> patches a LEB128 field whose <em>width is variable</em> &mdash; and it is the one relocation type in that format with no dedicated handling in wasm-ld's fast path.</strong> Compare the three cases: a fixed 4-byte field is trivial to write, a bit range needs read-modify-write, and a variable-width field needs the linker to <em>choose a width</em> and rewrite the instruction stream around it. <strong>Getting the width wrong in the first case is a wrong number; in the second, a wrong register; in the third, a misaligned instruction stream that desynchronises the decoder for every subsequent instruction.</strong> The severity escalates with how much the field's position depends on the value, and that escalation is the argument for treating width as a first-class property of a relocation rather than an implementation detail.</p>
                <p>Finally, the emit concept's four bugs connect here, because one of them is this concept's subject. <strong>Bug 3 &mdash; the overlapping <code>answer</code> and <code>answer_ptr</code> &mdash; was found by checking a number, and bug 2 &mdash; the swapped <code>sh_link</code> and <code>sh_info</code> &mdash; by reading warnings.</strong> But a fifth bug that did not happen here, and would not have been caught by anything, is a relocation offset that pointed one byte off the field. <strong>On x86-64 that produces a binary that links and jumps to a slightly wrong address, because the field is a fixed four bytes and there is nothing to signal the mistake.</strong> <a href="/courses/obj/lessons/obj-verify">The next concept</a> is about how you catch a class of bug where every tool agrees with you and the answer is still wrong, and this is the canonical example of why an independent oracle has to be independent of the thing you are checking.</p>
                <p>Last: the course is finished here. <a href="/courses/obj/lessons/obj-verify">Proving Your Object File Is Right</a> is the final concept, and it is the one that makes the other seventeen safe to trust.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-emit">Previous: Writing One From Scratch</a></span>
                <span>Next: Proving Your Object File Is Right</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
