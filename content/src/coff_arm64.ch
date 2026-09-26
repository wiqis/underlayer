// COFF Course — Module 5: Other Targets and Other Sections
// Concept: ARM64 relocations, from a real object — including the pairs that only
// make sense together, and a branch displacement whose width is an ISA fact.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_arm64() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("ARM64 Relocations — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>ARM64 Relocations</h1>
            <div class="lesson-meta">22 min &middot; Module 5: Other Targets and Other Sections &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The <a href="/courses/coff/lessons/coff-relocations">relocations concept</a> decoded the <code>IMAGE_REL_I386_REL32</code> and <code>IMAGE_REL_AMD64_REL32</code> families, and both of those are one instruction wide and mean the same thing: write a displacement. It would be easy to conclude that is what a COFF relocation <em>is</em>.</p>
                <p>It is not. Those two are the easiest cases in the table, and they are easy precisely because x86-64 displacements are uniform: four bytes, relative, sign-extended. A different instruction set has different needs, and ARM64 needs things x86-64 never asks for. It has a 26-bit branch field that caps how far a <code>bl</code> can reach. It has a 12-bit immediate that can only address within a page, so reaching a symbol needs a second instruction. And it has two different ways to encode that second instruction, so the same relocation name means two different things depending on a letter in it.</p>
                <p>So this concept does what the COFF course has done for every section: compile a real object for a real target and read the table. Five distinct relocation types come out of a file with four functions in it, and the interesting one is not any single type &mdash; it is the way two of them have to travel together.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Same ten bytes per entry, same two fields, as Module 2 established:</p>
                <div class="formula">
VirtualAddress    4 bytes   where in the section the fixup applies
SymbolTableIndex  4 bytes   which symbol it refers to
Type              2 bytes   what to compute and how wide the result is
                </div>
                <p>And the same structural observation from that concept applies with more force here: <strong>the two fields are independent</strong>, so a relocation's meaning is a function of both. The type says how to compute; the symbol says from what. A type table that is wrong for a target produces numbers, not errors.</p>
                <p>The thing that changes across targets is the third field's repertoire, and it changes because of the instruction set. Three properties of ARM64 drive everything below:</p>
                <table>
                    <thead>
                        <tr><th scope="col">ARM64 property</th><th scope="col">Consequence for a relocation</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A branch immediate is 26 bits, and bits 25 and 26 are fixed</td><td>Displacements are in units of 4 bytes and are <strong>signed 26-bit</strong>, so a call can reach &plusmn;128 MB and not one byte further</td></tr>
                        <tr><td>An unsigned 12-bit immediate offsets from the current PC</td><td>A data reference can only encode a 4 KB range, so anything further needs a <em>second</em> instruction holding the page number</td></tr>
                        <tr><td>There are two ways to form that page number</td><td>One form computes <code>page &minus; PCpage</code> for a nearby page, the other uses an absolute 32-bit page number &mdash; and the relocation name says which</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-warn">
                    <strong>The consequence worth internalising.</strong> On x86-64 a relocation is a self-contained instruction: apply it and the instruction is done. <strong>On ARM64 some relocations are not self-contained &mdash; they are half of a two-instruction idiom</strong>, and the two halves are two separate relocation entries at adjacent offsets, applying to the same symbol. That is not a compiler quirk or a toolchain accident. It is a property of the instruction set, faithfully recorded, and a linker that applies the halves independently produces an address that is wrong in a way that looks like a plausible address.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Four functions, compiled for a Windows ARM64 target:</p>
                <pre><code>$ clang --target=aarch64-pc-windows-msvc -c arm64.c -o arm64.obj
$ llvm-readobj --relocations arm64.obj
  Section (1) .text
    0x00 IMAGE_REL_ARM64_PAGEBASE_REL21   gvar
    0x04 IMAGE_REL_ARM64_PAGEOFFSET_12L   gvar
    0x18 IMAGE_REL_ARM64_PAGEBASE_REL21   gvar
    0x1C IMAGE_REL_ARM64_PAGEOFFSET_12L   gvar
    0x38 IMAGE_REL_ARM64_PAGEBASE_REL21   arr
    0x3C IMAGE_REL_ARM64_PAGEOFFSET_12A   arr
    0x64 IMAGE_REL_ARM64_BRANCH26         rd
    0x74 IMAGE_REL_ARM64_BRANCH26         wr</code></pre>
                <p>The tool wraps that in a <code>Relocations [ ]</code> block, and the section is named because a relocation list that does not say which section it belongs to is not much use.</p>
                <p>Five relocation types from four functions, and look at the offsets: <code>0x00</code> and <code>0x04</code>, then <code>0x18</code> and <code>0x1C</code>, then <code>0x38</code> and <code>0x3C</code>. <strong>Three pairs, four bytes apart, each pair naming the same symbol.</strong> Then two lone branches. That is the whole shape of ARM64 relocation in one screen, and it is nothing like the x86-64 table.</p>
                <h3>The pair</h3>
                <p>Disassemble the first four bytes and the pairing stops being an observation:</p>
                <div class="hex-dump">
                    <pre>0x00:  PAGEBASE_REL21   gvar
0x04:  PAGEOFFSET_12L   gvar
</pre>
                </div>
                <p>Those are the two halves of a single address. <code>PAGEBASE_REL21</code> fills a 21-bit signed field with the difference between the target's 4 KB page number and this instruction's page number &mdash; a <em>relative</em> page number, which keeps the immediate small and the code position-independent. <code>PAGEOFFSET_12L</code> fills a 12-bit unsigned field with the low 12 bits of the target's address, which is the offset within the page. Add them and you have the address:</p>
                <div class="formula">
address = (page_of(target) - page_of(this_instruction)) * 4096
        + (target and 0xfff)

       21 bits of signed field      12 bits of unsigned field
</div>
                <p>Twenty-one bits of signed page delta reaches &plusmn;4 MB of pages, so about &plusmn;2 GB of reach, and the 12 bits cover the page itself. Between them, any 32-bit address &mdash; without a relocation for the absolute case, which is the whole reason the split exists.</p>
                <p><strong>And the third pair is the interesting one, because it uses a different opcode for the same job.</strong> <code>0x38</code>/code> and <code>0x3C</code> are <code>PAGEBASE_REL21</code> plus <code>PAGEOFFSET_12A</code> &mdash; the <code>A</code> variant, not the <code>L</code> one &mdash; and both name <code>arr</code>. The two suffixes are the difference:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Name</th><th scope="col">Stands for</th><th scope="col">Fills</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>PAGEOFFSET_12A</code></td><td>ADRP</td><td>the low 12 bits of the absolute address</td></tr>
                        <tr><td><code>PAGEOFFSET_12L</code></td><td>literal, from <code>LDR</code></td><td>the low 12 bits of the address, via a literal pool entry</td></tr>
                    </tbody>
                </table>
                <p>So the compiler chose <code>ADRP</code> plus a load for the array and <code>ADRP</code> plus a literal-pool load for the globals. Same relocation for the page number, different relocation for the offset, and <strong>the only thing distinguishing them is a letter inside the type name.</strong> A relocator with a table that maps <code>PAGEOFFSET_12</code> to a single rule silently applies the wrong one to half the references in the file, and both results are valid 12-bit values.</p>
                <h3>The branch, and why 26 bits is a hard limit</h3>
                <p>The two <code>BRANCH26</code> entries at <code>0x64</code> and <code>0x74</code> are the calls, and the type is a complete description of the computation:</p>
                <div class="formula">
displacement = (target - (address_of_this_instruction + 4)) / 4
value        = displacement and 0x03ffffff      (26 bits)
then the linker verifies: (value sign-extended as 26 bits) * 4
                        must equal the displacement it just computed
</div>
                <p>Two things there are worth more than the arithmetic. <strong>The division by four is not optional</strong>, because the ARM64 branch field counts instructions, not bytes, and every ARM64 instruction is 4 bytes. A relocator that writes a byte displacement into a 26-bit field produces a call to a quarter of the intended offset. And <strong>the width is not a format decision at all</strong> &mdash; it is the instruction's own field size. The COFF table has 16 bits available for the type and uses them to say "26 bits, sign-extended, scaled by 4", because the format has to encode every target's branch widths in a shared namespace.</p>
                <p>Which gives the type a real job beyond arithmetic: <strong>range checking.</strong> A 26-bit signed field scaled by 4 reaches &plusmn;128 MB. If the target is further away, no value fits, and the honest response is to fail the link. A relocator that truncates instead produces a call to a plausible address within 128 MB &mdash; and on a large program, that address is inside some other function. This is the one place in COFF relocations where a correct implementation <em>must</em> reject rather than approximate, and it is worth noting that the i386 and AMD64 tables have no equivalent obligation: their displacements are 32-bit and effectively always fit.</p>
                <h3>The section flags, for contrast</h3>
                <p>The same <code>.text</code> in an i386 object and an ARM64 object:</p>
                <div class="hex-dump">
                    <pre>i386   .text  char=0x60500020
arm64  .text  char=0x60300020
</pre>
                </div>
                <p>Identical except in the alignment bits, which is the four-bit field from the characteristics concept. So a reader must take the alignment from the target's section header and must not assume it: the same section name, the same <code>CNT_CODE</code>, and a different alignment, purely because the target's preferred code alignment differs.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Applying the pair, by hand, to check the arithmetic a linker would do. Two pages: the instruction at <code>0x2000</code>, the symbol at <code>0x2010</code>. (Real numbers this time, from a linked image rather than an object, since a relocatable object has zeros.)</p>
                <div class="formula">
instruction at 0x2000,  target gvar at 0x2010

PAGEBASE_REL21
    page_of(target)    = 0x2010 / 0x1000 = 2
    page_of(this insn) = 0x2000 / 0x1000 = 2
    delta              = 2 - 2 = 0
    fits in 21 signed bits?  yes
    -> the field receives 0

PAGEOFFSET_12L
    low 12 bits of 0x2010 = 0x010
    fits in 12 unsigned bits?  yes
    -> the field receives 0x010

the pair now encodes: page 2, offset 0x010  =  0x2010
</div>
                <p>Now move the target across a page boundary, which is where the two fields start doing visibly different work. Instruction at <code>0x2ffc</code>, target at <code>0x3008</code>:</p>
                <div class="formula">
PAGEBASE_REL21
    page_of(target)    = 0x3008 / 0x1000 = 3
    page_of(this insn) = 0x2ffc / 0x1000 = 2
    delta              = 3 - 2 = +1 page  =  +0x1000 in bytes

PAGEOFFSET_12L
    low 12 bits of 0x3008 = 0x008

combined: 0x2000 + 0x1000 + 0x008 = 0x3008
</div>
                <p>Both fields stay small: one bit of page delta, three bits of offset. That is the design working. Now the case that breaks it &mdash; instruction at <code>0x1000</code>, target at <code>0x900000</code>, eight and a half megabytes away:</p>
                <div class="formula">
PAGEBASE_REL21
    page delta = (0x900000 / 0x1000) - (0x1000 / 0x1000)
               = 0x900 - 1 = 0x8ff = 2303 pages
    21 signed bits holds -1048576 .. 1048575, so 2303 FITS

still fine -- the relative form reaches 2048 pages = 8 MB either way
</div>
                <p>So the relative form's range is symmetric and generous, and the arithmetic is simple. The case that genuinely cannot be encoded is a <strong>negative</strong> page delta beyond 2 MB, or a target more than 128 MB away for a branch &mdash; and there the correct behaviour is to fail.</p>
                <p>Now the failure that is worth being able to recognise, because a relocator that misreads the <code>A</code>/<code>L</code> suffix produces it. Apply the <code>L</code> rule to a <code>PAGEOFFSET_12A</code> entry. For the <code>arr</code> pair at <code>0x38</code>/code> and <code>0x3C</code>, the 12-bit field is filled with the offset within the page &mdash; which is <em>also</em> what the <code>L</code> rule computes. So the two rules agree for the value and differ only in which instruction reads it, and the immediate consequence is that the <em>value</em> is right while the <em>meaning</em> is not.</p>
                <p>That is the uncomfortable part, and it is the reason this concept is worth the trouble. A relocator cannot detect its own error here from the numbers: it wrote a valid 12-bit immediate, and the section still has the right size, and the link succeeded. The error surfaces only when the program runs, and it surfaces as a load from the wrong address. <strong>Which is the strongest argument in this whole module for range checking and for the checks a format gives you for free</strong> &mdash; a rule that says "26 bits, sign-extended, scaled by 4, and if it does not fit, fail" is a rule that converts a silent wrong answer into a build error, and no amount of care in the relocator's arithmetic can do that for a rule it does not know is conditional.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=aarch64-pc-windows-msvc -c arm64.c -o arm64.obj
$ llvm-readobj --relocations arm64.obj
$ llvm-objdump -d --section=.text arm64.obj | head -30</code></pre>
                <ul>
                    <li><strong>Find more relocation types.</strong> Add code that takes a function's address into a register, that calls through a pointer, that branches conditionally at long range, that references a static data item, and that uses an <code>adrp</code>-free form. Each shape wants a different relocation, and the table you build from your own source is the one you will actually remember. Expect <code>ADDR32</code>, <code>ADDR64</code>, <code>ADRL_IMMEDIATE</code> and <code>JUMP26</code> to turn up.</li>
                    <li><strong>Force a long branch and watch it fail.</strong> Put a call more than 128 MB away. You cannot link ARM64 COFF on this machine &mdash; <code>ld</code> supports no <code>aarch64pe</code> emulation &mdash; so do it in assembly by hand: assemble an <code>adrp</code>-based long jump, or compute the displacement yourself and show that no 26-bit value exists. Seeing the range limit as an arithmetic impossibility rather than a linker error is the point.</li>
                    <li><strong>Disassemble the three pairs.</strong> At offsets <code>0x00</code>, <code>0x18</code> and <code>0x38</code> you should find three two-instruction sequences, and the third should use a different second instruction from the first two. Reading the actual opcodes is what turns "two relocations at adjacent offsets" into "an <code>adrp</code> and a load".</li>
                    <li><strong>Build the type table properly.</strong> Write out the ARM64 relocation types you have observed, with their field width, signedness, scale factor, and whether they are one half of a pair. Then write the validation each one needs. The scale factor and the range check are the two that people leave out, and they are the two that matter.</li>
                    <li><strong>Compare three targets side by side.</strong> Produce i386, x86-64 and ARM64 objects from equivalent source and diff the relocation type sets. The set of types a target needs is a direct readout of what its instruction set cannot express &mdash; and having seen that once, you will not be surprised by another architecture's table.</li>
                    <li><strong>Check the alignment difference.</strong> <code>.text</code> is <code>0x60500020</code> on i386 and <code>0x60300020</code> on ARM64. Read the alignment out of each with the parser shipped with this course, and then check which alignment the ARM64 relocations actually require &mdash; a 4-byte-aligned instruction field inside a 16-byte-aligned section is a constraint the section header is not obliged to state.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an object has relocations at <code>0x00</code> and <code>0x04</code>, both naming the same symbol &mdash; the first <code>IMAGE_REL_ARM64_PAGEBASE_REL21</code>, the second <code>IMAGE_REL_ARM64_PAGEOFFSET_12L</code>. The instruction at <code>0x2000</code>; after linking, the symbol is at <code>0x3008</code>. What goes in each field, and why must a relocator treat the two entries as one operation rather than two?</p>
                <div class="quiz" id="quiz-coff-arm64-1">
                    <button class="quiz-option" data-correct="true" data-explain="The two fields carry different halves of one address and neither is meaningful alone. The page-base field gets the signed difference of the two page numbers, which here is 3 minus 2, so plus one page, and it is stored in 21 signed bits so the value stays position-independent and small. The page-offset field gets the low twelve bits of the target, 0x008, unsigned. The two must be applied as a unit because each is only half the address: read the page field alone and you have a page number with no offset, read the offset alone and you have an offset into a page you have not identified, and both are valid-looking numbers. The pairing is also why the entry at 0x04 is four bytes after 0x00: the two halves fill two adjacent four-byte instructions." onclick="checkQuiz('quiz-coff-arm64-1', this)">The page field gets +1 (the page-number difference) and the offset field gets <code>0x008</code>. They are two halves of one address, so a relocator that applies or validates them independently has a value that is a valid page number and a valid offset belonging to no particular page</button>
                    <button class="quiz-option" data-correct="false" data-explain="That conflates the two 12-bit and 21-bit fields with the wrong pairing. The page-base field is what carries the distance between the pages and it is 21 bits wide, signed, because it is the field that can be negative. The 12-bit field carries only the offset within the page, which is 0x008 here and is always unsigned. Getting the widths the wrong way round is what produces a relocator that writes a page delta into a 12-bit field and truncates." onclick="checkQuiz('quiz-coff-arm64-1', this)">The page field gets <code>0x1000</code> and the offset field gets <code>3</code>, because the 12-bit field holds the page number and the 21-bit field holds the offset within the page</button>
                    <button class="quiz-option" data-correct="false" data-explain="A page delta of plus one is well within the range of a 21-bit signed field, and the offset 0x008 is well within twelve unsigned bits, so no value here is unrepresentable. The scale-by-four and range check belong to BRANCH26, which is a different relocation with a different field: a 26-bit branch counts instructions, so its displacement is in units of four bytes and caps at 128 MB. Confusing the two relocation families is the mistake here, not a range failure." onclick="checkQuiz('quiz-coff-arm64-1', this)">The page field gets +1 and the offset field gets <code>0x008</code>, but no 21-bit value can represent a page delta of +1, so the linker must report a range error</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You maintain a relocator that reads COFF objects for several targets. It is correct for i386 and x86-64 and has just been extended to ARM64. Objects for ARM64 now link without errors, but the program loads the wrong value from one global array and crashes somewhere unrelated. The same source, built for x86-64, works. Given this concept, what is your leading hypothesis, and what is the cheapest check that distinguishes it from the other two plausible causes?</p>
                <div class="quiz" id="quiz-coff-arm64-2">
                    <button class="quiz-option" data-correct="true" data-explain="The pattern narrows it sharply. One global array is wrong while everything else is right, the x86-64 build of the same source is fine, and the failures appear only on the new target. The third fact is the decisive one: a compiler emitting both an ADRP page number and a load of the low twelve bits is choosing between the A and L forms, and the only thing distinguishing them in the relocation table is a single letter inside the type name. A relocator written from a table of names that drops or merges that suffix applies the wrong rule to one of the two, writes a value that is still a legal 12-bit immediate, and produces a link that succeeds and a load from the wrong address. The cheap check is to diff the relocation type sets between the working and failing objects: if the failing one uses a type name your table does not have a distinct entry for, you have your answer in one command. The general lesson is that a table-driven relocator is only as good as its table's coverage, and coverage is exactly what a new target breaks." onclick="checkQuiz('quiz-coff-arm64-2', this)">Your type table does not distinguish <code>PAGEOFFSET_12A</code> from <code>PAGEOFFSET_12L</code>, so it applies the literal-pool rule to the <code>ADRP</code> form. The written value is still a legal 12-bit immediate, so nothing fails. The cheapest check is to diff the relocation type sets of the working and failing objects</button>
                    <button class="quiz-option" data-correct="false" data-explain="Worth ruling out, and the scale factor is a real trap, but it does not fit the symptom. Branch26 scaling only affects calls and branches, and a wrong scale there would misdirect control flow rather than load a wrong value from a global array. The reported failure is a data load, which points at the address-forming relocations rather than the branch family, and the fact that only one array is affected rather than every call also argues against a scale bug." onclick="checkQuiz('quiz-coff-arm64-2', this)">The relocator is not dividing branch displacements by four, so calls are going to a quarter of the intended offset and the crash is a symptom of that rather than of the array access</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the third candidate and it is the one that is usually checked first, but here the objects link successfully, which is the signal that the range is fine. A displacement that cannot be represented produces a link error from any implementation that performs the check, not a successful link with a wrong value. And a silent truncation would affect the largest offsets in the file rather than one specific array, so the pattern does not match either." onclick="checkQuiz('quiz-coff-arm64-2', this)">The page-number delta does not fit in 21 bits, your relocator truncates instead of failing, and the result is a plausible address in the wrong page</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a table-driven tool meets a new input, the most likely failure is a missing row rather than a wrong computation. Diff the key sets before you debug the arithmetic.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the payoff for the claim <a href="/courses/coff/lessons/coff-relocations">the relocations concept</a> made and then had to hedge: that a single hard-coded table of relocation numbers is correct only for the target it was written for. The module's own exercise used an x64 reader meeting ARM64 objects as the illustration, and this concept is the demonstration. The lesson generalises past COFF &mdash; every object format has per-architecture relocation namespaces, and ELF's are separated by machine precisely so that a reader is forced to select rather than assume.</p>
                <p>The pairing is the part that generalises too, and it is the same structural point as the COMDAT checksum in <a href="/courses/coff/lessons/coff-comdat-linking">the COMDAT concept</a>. A relocation here is not a self-contained request; it is half of a claim that only means something next to its partner. A linker that applies entries independently, without knowing which are related, gets no error &mdash; it gets two correct-looking numbers that do not add up to an address. That is the same failure mode as a relocator that trusts a checksum it never read, and it is worth noticing that both are cases where the format gave you the information and the consumer had to know to use it.</p>
                <p>The <code>BRANCH26</code> range check is the other end of the concept, and it connects to something the whole course has been circling. <a href="/courses/coff/lessons/coff-linking">The link concept</a> computed <code>0x401020 - 0x401012 = 0x0e</code> and noted that a 32-bit displacement effectively always fits. Here the field is 26 bits, and it does not always fit. <strong>A relocation type is partly an arithmetic recipe and partly a promise about range</strong>, and the second half is the half that makes a linker safe: it is what turns "I could not represent this" into a build failure instead of a number.</p>
                <p>Two more sections in this module, and neither is about relocations. One is a section that exists to carry text <em>to</em> the linker rather than code to the processor, and the other is the section that makes a variable's address depend on which thread is asking. Both are cases of COFF carrying information that is not part of the program.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-tls">Thread Local Storage</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-comdat-linking">Previous: COMDAT in the Linker</a></span>
                <span><a href="/courses/coff/lessons/coff-tls">Next: Thread Local Storage</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
