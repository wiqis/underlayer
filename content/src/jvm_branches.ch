// JVM Course — Module 2: Members and Code
// Concept: two offset conventions in one attribute, the switch alignment trap,
// the exception table, and the wide prefix.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_branches() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Two Offset Conventions — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Two Offset Conventions</h1>
            <div class="lesson-meta">24 min &middot; Module 2: Members and Code &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>This concept is about a trap so specific and so well-hidden that it is worth a whole lesson on its own: <strong>the class file format uses two different conventions for what a branch offset means, both of them inside the same attribute, and nothing in the bytes says which is which.</strong></p>
                <p>Offsets in <em>instructions</em> are relative to the address of the branch instruction itself. Offsets in the <em>exception table</em> are absolute positions in the code array. Both are two-byte or four-byte unsigned or signed numbers. Both appear in the same <code>Code</code> attribute. <strong>A reader that applies the wrong convention does not error &mdash; it computes a destination that is a valid offset, just not the intended one.</strong></p>
                <p>And the error is not a constant. It is <em>the position of the branch</em>, so every branch in a method is wrong by a different amount. A disassembler built on the wrong convention produces output that looks structurally perfect: real offsets, real instruction boundaries, plausible destinations. It is wrong everywhere and visibly so only if you know where to look.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Both conventions, stated side by side, because the whole point is that they are easy to confuse:</p>
                <div class="formula">
CONVENTION A -- INSTRUCTION BRANCH OFFSETS
    the stored value is RELATIVE to the address of the opcode
    that contains it.

    destination = address_of_this_instruction + stored_offset

    applies to:  if&lt;cond>, goto, jsr, ifnull, ifnonnull,
                tableswitch, lookupswitch
    the offset is SIGNED, two bytes for the conditional forms


CONVENTION B -- EXCEPTION TABLE OFFSETS
    the stored value is an ABSOLUTE index into the code array.

    destination = stored_offset, counted from byte 0 of code

    applies to:  start_pc, end_pc, handler_pc
    `to` (end_pc) is EXCLUSIVE: the protected range is [from, to)


CONVENTION C -- LineNumberTable AND STACKMapTable
    also absolute, counted from byte 0 of the code array.

    three conventions, two of them absolute, and the odd one out
    is the one that looks like the others.
</div>
                <p>Convention A is the anomaly and it is worth asking why. <strong>The answer is position independence, and it is a good reason.</strong> An absolute offset would mean that moving a method's code within the array, or the method within the class, required rewriting every branch. A relative offset survives both, because the branch and its target move together. The same reasoning is why <a href="/courses/elf/lessons/relocation-entries">an x86 or ARM <code>jmp</code> is relative</a> and why <a href="/courses/pe/lessons/pe-imports">a PE import thunk is a relative <code>jmp</code></a>.</p>
                <p>But note the cost, because it is not free: <strong>the relative offset cannot be read without knowing where the instruction is</strong>, which means a reader that scans for opcodes must track a position even for instructions it does not care about, and a disassembler cannot print a target without also printing the instruction's own address. The absolute tables have no such coupling. <strong>Convention A buys relocatability with a dependency on position; conventions B and C buy simplicity with a dependency on stability.</strong> A format that never moves code could use absolute everywhere, and this one cannot.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The switch alignment, which is a trap inside a trap</h3>
                <p>Before the two conventions can be demonstrated they have to be read past a padding rule, because the two switch opcodes are the only instructions in the format with variable-length operands that are not length-prefixed:</p>
                <div class="hex-dump">
                    <pre>  tableswitch, 48 bytes of code, opcode at offset 1:

    00: 1b                    iload_1
    01: aa                    tableswitch
    02: 00 00                 2 bytes of PADDING
    04: 00 00 00 2d           default   = 45
    08: 00 00 00 00           low       = 0
    0c: 00 00 00 04           high      = 4
    10: 00 00 00 23           target[0] = 35   &lt;- RELATIVE, not absolute
    14: 00 00 00 25           target[1] = 37
    18: 00 00 00 27           target[2] = 39
    1c: 00 00 00 29           target[3] = 41
    20: 00 00 00 2b           target[4] = 43
    24: 04 ac                 iconst_1 ; ireturn
    ...
</pre>
                </div>
                <p><strong>The padding exists to 4-byte-align the operands, and the alignment is measured from the start of the code array, not from the instruction.</strong> The opcode is at offset 1, the operands would start at 2, and the next 4-byte boundary is 4 &mdash; so exactly two bytes of padding. Every one of those numbers is checkable against the file, and the arithmetic above is what this course's decoder reads.</p>
                <p>Now apply convention A. The stored targets are 35, 37, 39, 41, 43 and the default is 45. <strong>The instruction is at offset 1, so the real destinations are 36, 38, 40, 42, 44 and 46.</strong> And here is the confirmation, from <code>javap -c</code> on the same file:</p>
                <div class="hex-dump">
                    <pre>  $ javap -c Shapes.class
             1: tableswitch      // 0 to 4
                       0: 36
                       1: 38
                       2: 40
                       3: 42
                       4: 44
                 default: 46
                 -- end of switch
            36: iconst_1
            38: iconst_2
            40: iconst_3
            42: iconst_4
            44: iconst_5
            46: iconst_0
</pre>
                </div>
                <p>Six numbers, and every one is the stored value plus one. <strong>The stored values are not destinations; they are displacements, and the only thing that turns them into addresses is knowing where the instruction was.</strong></p>
                <p>The <code>lookupswitch</code> in the same class behaves identically, with a different layout &mdash; a match/target pair list instead of a dense range, and a <em>count</em> rather than a high value:</p>
                <div class="hex-dump">
                    <pre>    00: 1b                 iload_1
    01: ab                 lookupswitch
    02: 00 00              2 bytes of padding, same rule
    04: 00 00 00 2c        default  = 44
    08: 00 00 00 03        npairs   = 3
    0c: 00 00 00 01 00 00 00 23    match 1     -> 35  -> real 36
    14: 00 00 00 64 00 00 00 26    match 100   -> 38  -> real 39
    1c: 00 00 27 10 00 00 00 29    match 10000 -> 41  -> real 42
</pre>
                </div>
                <h3>Now the exception table, in the same method</h3>
                <p>Here is the contrast, and it needs no arithmetic at all &mdash; the numbers <code>javap</code> prints are the numbers in the file:</p>
                <div class="hex-dump">
                    <pre>  $ javap -c Shapes.class        (trycatch, same class)
         Exception table:
            from    to  target type
                0     5    10   Class java/lang/ArithmeticException
                0     5    18   Class java/lang/RuntimeException
                0     5    27   any
               10    13    27   any
               18    22    27   any
               27    29    27   any
</pre>
                </div>
                <p>Offset 10 is where the <code>ArithmeticException</code> handler begins, and the file says 10. <strong>No adjustment, and that is the point.</strong> The same two-byte field, in the same attribute, twenty bytes further on, means something different. A reader that applied convention A here would add each handler's own position &mdash; and handler 1's position <em>is</em> 10, so it would report 20 and be wrong by ten, while handler 3 at position 27 would be reported as 54 and be wrong by twenty-seven. <strong>Three handlers, three different errors, none of them the same as the other.</strong></p>
                <p>Two further details in that table, both easy to get wrong. <strong><code>to</code> is exclusive</strong>: the first row protects <code>[0, 5)</code>, which is <code>bipush 100; iload_1; idiv; istore_2</code> &mdash; the division and its result, and not the <code>ifle</code> that follows. And <strong>rows are tried in order</strong>, so the three rows covering <code>[0, 5)</code> form a chain: arithmetic first, then runtime, then any. That is the compiled form of a <code>catch</code> list followed by a <code>finally</code>, and the <code>any</code> rows at offsets 10, 18 and 27 are the <code>finally</code> block being entered from each exit path.</p>
                <div class="callout callout-warn">
                    <strong>And the reason the two conventions differ is worth stating, because it explains which one you will meet where.</strong> A branch offset is relative because the branch and its target must be able to move together &mdash; the code array can be relocated, and a relative offset survives. An exception table offset is absolute because <strong>the exception table is not code</strong>: nothing relocates it, it is a table that happens to live inside the <code>Code</code> attribute, and making it relative would buy nothing while making every handler lookup an addition. The tables are index-like and the branches are code-like, and each gets the convention its own kind of thing deserves. <strong>The trap exists only because the format put both inside one attribute</strong> &mdash; a different design would have put the exception table in its own top-level block, where its offsets would be obviously a different kind of number, as <a href="/courses/elf/lessons/relocation-entries">a COFF relocation table</a> and <a href="/courses/dwarf/lessons/dwarf-address-to-line">a DWARF line table</a> both do.
                </div>
                <h3>The wide prefix</h3>
                <p>One more instruction-encoding detail, and the reason it exists is arithmetic rather than design. A local variable index is <strong>one byte</strong>, which caps it at 255 &mdash; and 256 does not fit. So there is a prefix opcode that widens the index that follows:</p>
                <div class="hex-dump">
                    <pre>    c4 36 01 00          wide istore 256      4 bytes
    36 01                 istore 1              2 bytes
    36 ff                 istore 255            2 bytes, the maximum
                              without the prefix

  0xc4 widens exactly ten opcodes: iload, lload, fload, dload,
  aload, istore, lstore, fstore, dstore, astore -- plus ret and
  iinc. Nothing else may carry it.

  verified on a generated class with 300 live locals:
    max_locals = 303
    96 real wide prefixes
    the first is c4 36 01 00 = wide istore 256, at code offset 1139
    the preceding instruction is an unprefixed istore 255
</pre>
                </div>
                <p><strong>The prefix appears at exactly 256 and not before</strong>, because that is the first index a single byte cannot hold. This is the same class of decision as the <a href="/courses/elf/lessons/elf-header-fields">ELF header's</a> choice of field widths, and the same trap it creates: a reader that assumes a single instruction width will desynchronise at exactly one point, and the bytes there are a plausible opcode followed by a plausible index. The mitigation is the same too &mdash; <strong>decode the instruction stream and check the position against <code>code_length</code></strong>, which is the assertion from the previous concept, because here it is the only thing that will notice.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>One number that confirms both conventions at once, which is the most efficient verification this course has found. The <code>StackMapTable</code> of the <code>tableswitch</code> method is eight bytes:</p>
                <div class="hex-dump">
                    <pre>  00 06 24 01 01 01 01 01
      |  |  +-- five more frames, each one byte, frame_type 0x01
      |  +----- frame_type 0x24 = 36, a same_frame at offset 36
      +-------- 6 frames

  a StackMapTable frame's offset is ABSOLUTE (convention C), and
  frame N's offset is:

      first frame:  offset = frame_type
      later frames:  offset = previous_offset + frame_type + 1

  which gives:
      frame 0:  36
      frame 1:  36 + 1 + 1 = 38
      frame 2:  38 + 1 + 1 = 40
      frame 3:  42
      frame 4:  44
      frame 5:  46
</pre>
                </div>
                <p>So the six frames are at offsets <strong>36, 38, 40, 42, 44, 46</strong>. And the switch's six destinations, after adding the opcode's address of 1, are <strong>36, 38, 40, 42, 44, 46</strong>.</p>
                <p><strong>The same six numbers, from two different mechanisms.</strong> One is a table of absolute frame positions, read directly. The other is a list of relative displacements that only become positions once the instruction's own address is added. They agree to the byte, and that agreement is the proof: <strong>a relative branch that was misread as absolute would put the frames at 35, 37, 39, 41, 43, 45, which are all odd numbers pointing into the middle of instructions, and the frames would not line up with anything.</strong></p>
                <p>That is what a cross-check like this is for. Neither number is self-evidently right on its own &mdash; one is a table of integers and the other is a table of displacements, and a reader that has the arithmetic subtly wrong will produce a self-consistent wrong answer in both. <strong>Two independent derivations landing on the same six values is the only evidence that both are right</strong>, and it is much stronger than either table looking plausible.</p>
                <p>What makes this particular cross-check available is a coincidence of the sample: the <code>tableswitch</code> method's only branches <em>are</em> its six destinations, so every frame has a branch and every branch has a frame. <strong>When you design a sample, designing it so two independent structures must agree is worth more than adding a tenth feature</strong> &mdash; and it is why the next concept can be written at all, since the frame offsets are the subject.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -c -p out/Shapes.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Shapes.class</code></pre>
                <ul>
                    <li><strong>Compute the switch padding yourself.</strong> Find the opcode's offset, add one, and work out how many bytes of padding reach the next 4-byte boundary. <strong>Then change the method so the opcode lands at a different offset and check the padding changes</strong> &mdash; that is what makes it alignment rather than a fixed cost, and it is a two-minute experiment.</li>
                    <li><strong>Write a disassembler with the wrong convention and see the damage.</strong> Print switch targets as the raw stored values. Every one will be off by the opcode's own position, which is a different amount at every switch in the file. <strong>Then find one where the wrong answer still lands on an instruction boundary</strong> &mdash; that is the case that would survive review.</li>
                    <li><strong>Apply the relative rule to an exception table and watch it fall apart.</strong> Add each handler's own position to its stored <code>handler_pc</code>. Handler 1 is at 10 and reports 20; handler 3 is at 27 and reports 54. <strong>Three handlers, three different errors, and the <code>any</code> rows all point at 27 so they all get the same wrong answer</strong> &mdash; which makes the failure look consistent when it is not.</li>
                    <li><strong>Check the <code>to</code> exclusivity by hand.</strong> For the <code>[0, 5)</code> row, name the four instructions at offsets 0 to 4 and the one at offset 5. <strong>Confirm the division is inside the protected range and the comparison is not</strong>, which is what the compiler's <code>try</code> block actually covers.</li>
                    <li><strong>Build the 300-local class and find the wide boundary.</strong> Confirm <code>max_locals</code> is 303, find the first <code>0xc4</code>, and check the index it widens is exactly 256. <strong>Then look at the instruction immediately before it</strong> and confirm its index is 255 with no prefix, so the boundary is exactly where the arithmetic says it is.</li>
                    <li><strong>Cross-check the frames against the branches yourself.</strong> Decode the <code>StackMapTable</code>'s six offsets, decode the switch's six destinations with the relative rule applied, and confirm they match. <strong>Doing this once by hand is the single most convincing check in the course</strong>, and it takes about ten minutes.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: in a 48-byte method, a <code>tableswitch</code>'s opcode is at offset 1 and its five stored targets are 35, 37, 39, 41, 43 with a stored default of 45. What are the real destinations, how many bytes of padding precede the operands, and what would a reader report if it treated the stored values as absolute?</p>
                <div class="quiz" id="quiz-jvm-branches-1">
                    <button class="quiz-option" data-correct="true" data-explain="Three separate things, and the padding has to be right before the targets can even be located. The opcode is at offset 1, so the operands would begin at offset 2, and the next 4-byte boundary measured from the start of the code array is offset 4. That is two bytes of padding. The stored targets are displacements relative to the address of the opcode, so each needs 1 added: 36, 38, 40, 42, 44, and the default becomes 46. A reader treating them as absolute reports 35, 37, 39, 41, 43 and 45, and the tell is that those are all odd numbers landing in the middle of two-byte instructions rather than on instruction boundaries. The reason the mistake is so durable is that the wrong answers are still small, still valid offsets, and still inside the method, so nothing structural fails. The other thing worth noticing is the asymmetry with the exception table in the same attribute, whose offsets really are absolute: a reader that has learned one convention from the switches will confidently apply the wrong one to the handlers, and there the error is a different amount at each row." onclick="checkQuiz('quiz-jvm-branches-1', this)">Destinations 36, 38, 40, 42, 44 with default 46, because the stored values are displacements from the opcode's address of 1. Two bytes of padding, since the operands start at offset 2 and the next 4-byte boundary is 4. Treating them as absolute gives 35, 37, 39, 41, 43 &mdash; all odd, all mid-instruction</button>
                    <button class="quiz-option" data-correct="false" data-explain="The targets are right and the padding figure is wrong, and the padding is not a detail here: it is what tells you where the operands begin, so getting it wrong means reading the default as the low value and every target one field late. The rule is that alignment is measured from the start of the code array, not from the instruction. The opcode sits at offset 1, the operands would start at offset 2, and the next multiple of four at or after 2 is 4 &mdash; so the gap is two bytes, not three. It is worth being careful about the boundary condition: a case where the operand start is already aligned would take zero bytes of padding, so the amount genuinely varies with the opcode's position, and computing it from the position is the only reliable way rather than assuming a fixed cost." onclick="checkQuiz('quiz-jvm-branches-1', this)">Destinations 36, 38, 40, 42, 44 with default 46, and three bytes of padding to align the operands to a 4-byte boundary measured from the start of the code array</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a bytecode-to-source mapper. It reports correct line numbers for most of a large codebase. For methods containing a <code>tableswitch</code> or a <code>try</code>/<code>catch</code>, it reports line numbers that are off, and the offsets it prints are always <em>smaller</em> than the ones <code>javap</code> prints. Everything else about those methods is correct: the instruction stream decodes cleanly, the method boundaries are right, the line table is read correctly. The error is always negative. What is the defect, what does the consistent sign of the error tell you, and what is the general habit for handling a field whose meaning depends on where it appears?</p>
                <div class="quiz" id="quiz-jvm-branches-2">
                    <button class="quiz-option" data-correct="true" data-explain="The consistent sign is the most informative part of the report and it narrows the diagnosis to almost nothing. Every error is negative, which means the tool is reporting an offset smaller than the true one, and the only mechanism in this concept that subtracts rather than adds is treating a relative displacement as if it were absolute: the true destination is the stored value plus the instruction's position, and a tool that stops at the stored value is short by exactly that position. The fact that the failures are confined to methods with switches or handlers is consistent, because those are the only constructs carrying offsets the tool has to resolve, and an exception table's stored offsets are genuinely absolute so they should not be affected at all, which is worth checking as a discriminator. The habit for the general case is that a field's meaning is a property of the structure that contains it, not of the field, so a decoder should never resolve an offset until it knows which table it came from. Concretely: keep stored values stored, and convert to addresses in one place at the end, at which point the convention is a parameter rather than a habit. A decoder that resolves offsets during parsing has baked the convention into the wrong layer and will get exactly one of these two cases right." onclick="checkQuiz('quiz-jvm-branches-2', this)">The tool treats relative branch offsets as absolute, so it reports each switch target short by the instruction's own position. The consistently negative sign is the tell: only the relative convention loses value that way. Keep stored offsets stored and convert once at the end, where the convention is a parameter rather than a habit baked into the parser</button>
                    <button class="quiz-option" data-correct="false" data-explain="This would produce errors in both directions rather than consistently negative ones, and the report says the sign is always the same, which is the strongest single piece of evidence available. A mis-derived padding rule shifts where the operands are read from, so the values recovered are wrong by an amount that depends on the padding, and that amount goes up and down with the opcode's position in the method. The report also says the instruction stream decodes cleanly and the method boundaries are right, which a padding error would very likely break, because a misread switch operand shifts everything after it. The failure is confined to the reported offsets, not to the decoding, and that is a conversion problem rather than a framing one." onclick="checkQuiz('quiz-jvm-branches-2', this)">The tool is miscomputing the switch padding, so it reads the operands from the wrong offset and gets a systematically wrong set of targets. The fix is to align the operands to a 4-byte boundary measured from the start of the code array</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: an offset's meaning is a property of the table it came from, not of the field. Keep stored values stored, and resolve to addresses in one place &mdash; then the convention becomes a parameter you can pass rather than a habit you can forget.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Relative branch offsets are not a JVM peculiarity but the universal choice for anything that relocates, and the collection is full of the comparison. <a href="/courses/elf/lessons/relocation-entries">An ELF <code>R_X86_64_PC32</code> relocation</a> is the same idea at link time: the addend is a displacement, not an address, precisely so the linker can move code. <a href="/courses/pe/lessons/pe-imports">A PE import thunk is a five-byte <code>jmp</code> through a relative pointer</a> for the same reason. <a href="/courses/coff/lessons/coff-relocations">A COFF <code>IMAGE_REL_I386_REL32</code></a> again. <strong>Every format that patches addresses into code uses a displacement rather than an absolute value, and every one of them is choosing relocatability over simplicity in exactly the same trade.</strong></p>
                <p>What the JVM adds is the <em>table</em> convention alongside the code one, and that is rarer. <a href="/courses/elf/lessons/relocation-entries">An ELF relocation's offset field</a> is absolute &mdash; it says where in the section to patch &mdash; and so is a <a href="/courses/dwarf/lessons/dwarf-address-to-line">DWARF line-table entry's address</a>, and so is <a href="/courses/pe/lessons/pe-base-relocations">a PE base relocation's target rva</a>. <strong>So the JVM is not unusual in having two conventions; what is unusual is putting both inside one attribute</strong>, where nothing marks the difference. Every other format keeps them in separate structures &mdash; code in a section, tables in a section &mdash; so a reader knows which convention applies from where it is reading.</p>
                <p>The switch padding is the same alignment discipline as <a href="/courses/wasm/lessons/wasm-instructions">WebAssembly's block-type lookahead</a> in one sense and the exact opposite in another. Both are variable-width operands that have to be located before they can be read. WebAssembly's problem is a one-byte peek, which is cheap; the JVM's is a 4-byte alignment rule, which is why every disassembler for the JVM has had this bug at least once. <strong>Compare <a href="/courses/pe/lessons/pe-alignment">a PE section's alignment</a>, where the same arithmetic appears at file-layout scale</strong> &mdash; the rule that a loader rounds an offset up to a power of two is the rule the switch is applying to its own operands.</p>
                <p>The <code>wide</code> prefix connects to something this course has already established twice. It is the same shape as the <a href="/courses/elf/lessons/elf-header-fields">ELF header</a> choosing a 2-byte <code>e_machine</code> and a 4-byte <code>e_entry</code> to match the ranges each field needs, and the same shape as <a href="/courses/coff/lessons/coff-bigobj">a format running out of address bits and growing a second header</a>. <strong>The prefix exists because the format chose one byte for compactness and then had a value that did not fit, and the fix was to add an escape rather than widen the field</strong> &mdash; paying a byte on the rare instruction rather than a byte on every one. That is the correct trade and it is the same reasoning behind <a href="/courses/wasm/lessons/wasm-leb128">a variable-width integer</a> in a different format.</p>
                <p>Next: <a href="/courses/jvm/lessons/jvm-stackmaps">the verifier's data</a> &mdash; where the six frame offsets computed above turn out to be the subject, and where a type checker writes its conclusions into the file the verifier is about to check.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-code">Previous: The Code Attribute</a></span>
                <span><a href="/courses/jvm/lessons/jvm-stackmaps">Next: The Verifier's Data</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
