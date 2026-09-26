// WebAssembly Course — Module 4: Data Placement
// Concept: the data section, its three forms, and the datacount section that
// exists only to let an earlier section be checked.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_data() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Data Section and DataCount — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>The Data Section and DataCount</h1>
            <div class="lesson-meta">21 min &middot; Module 4: Data Placement &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The data section is the <a href="/courses/wasm/lessons/wasm-elements">element section</a>'s twin: it fills <a href="/courses/wasm/lessons/wasm-tables-memories">memories</a> instead of tables. It has three forms rather than eight, it is the last section in the file, and it brings with it a section that exists for no other reason &mdash; <strong>datacount</strong>, which appears before the code section purely so the code section can be checked against it.</p>
                <p>That section is the most interesting thing here, because it inverts the format's normal shape. Every other section is self-contained: the type section is valid on its own, the code section is valid on its own, the data section is valid on its own. The code section, though, contains <code>memory.init</code> and <code>data.drop</code> instructions that name data segment indices &mdash; and <strong>those instructions live in a section that appears before the data section that defines them</strong>. Without help a validator would have to either accept the indices unchecked or read the whole file twice.</p>
                <p>So the format inserts a four-byte section between the element section and the code section containing nothing but a count. It is a forward declaration, and it is the only section in the format whose entire purpose is to make a later section checkable. <strong>It is a compromise that trades bytes for single-pass validation, and the reason the compromise was necessary rather than merely convenient is worth understanding.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three forms, and the split is the same one the element section made &mdash; active or passive, implicit or explicit memory &mdash; minus the expression variant, because a data element is always a raw byte string:</p>
                <div class="formula">
data section:
    count                       how many segments follow

segment:
    flags                       0, 1 or 2
    ...then:

  flags = 0   active, memory 0
      offset                   a constant expression
      size                     a LEB128 byte count
      bytes                    exactly that many raw bytes

  flags = 1   passive
      size                     a LEB128 byte count
      bytes                    exactly that many raw bytes

  flags = 2   active, explicit memory index
      memory_index            a LEB128
      offset                   a constant expression
      size                     a LEB128 byte count
      bytes                    exactly that many raw bytes
</div>
                <p><strong>There is no expression form for a data segment, and there never will be one</strong> &mdash; the element section has four extra forms because a table element can be a computed reference, and a data element is bytes. That is not an oversight in the element section's design; it is the reason the two sections have different shapes, and it is the clearest evidence that the eight element forms were added for a capability the data section never needed.</p>
                <p>And notice what the byte count is doing: <strong>it is a size in bytes, not a count of elements.</strong> A data segment is an opaque string, so the only way to know where it ends is to be told its length. This is the first place in the format where a payload is a counted blob rather than a sequence of self-describing records, and it is why a data section cannot be walked by reading structure &mdash; you read the count and then skip that many bytes.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>All three forms, each in its own minimal module, hand-assembled and each accepted by <code>wasm-validate</code> and read back by wabt. The segment bytes first, then the readers' verdicts:</p>
                <div class="hex-dump">
                    <pre>  form 0   00 41 00 0b 04 61 62 63 64
          |   |  |     |  +------- "abcd", four raw bytes
          |   |  |     +---------- size = 4
          |   |  +---------------- offset: i32.const 0 ; end
          |   +------------------- flags = 0, active into memory 0
          +-----------------------

  form 1   01 04 70 61 73 73
          |   |  +----------- "pass"
          |   +-------------- size = 4
          +------------------ flags = 1, PASSIVE: no memory, no offset

  form 2   02 00 41 00 0b 04 61 62 63 64
          |   |  |  |     |
          |   |  |  |     +------- "abcd"
          |   |  |  +------------ size = 4
          |   |  +--------------- offset: i32.const 0 ; end
          |   +------------------ memory index = 0
          +---------------------- flags = 2, active into an EXPLICIT memory
</pre>
                </div>
                <p>And the two readers, independently:</p>
                <div class="hex-dump">
                    <pre>  $ wasm-validate data0.wasm   &amp;&amp; echo VALID
  VALID
  $ wasm-objdump -x data0.wasm | sed -n '/^Data/,$p'
  Data[1]:
   - segment[0] memory=0 size=4 - init i32=0
    - 0000000: 6162 6364          abcd

  ...and for the passive one:
   - segment[0] passive size=4
    - 0000000: 7061 7373          pass
</pre>
                </div>
                <p>Three observations, each of which is a place a reader can go wrong. <strong>Form 0 and form 2 differ only by one byte</strong> &mdash; the explicit memory index &mdash; and for a module with one memory they are semantically identical, which is exactly the pattern the element section followed and exactly the reason a reader that treats <code>0x00</code> and <code>0x02</code> as unrelated shapes will miss the difference. <strong>The passive form has no offset and no memory index at all</strong>, so its size byte sits immediately after the flags byte, and a reader that expects an offset expression will read the size as an opcode. <strong>And the data is raw</strong>: <code>61 62 63 64</code> is <code>"abcd"</code> and there is no encoding step, no escaping, no NUL terminator, no length prefix beyond the section's own framing.</p>
                <p>That last point is worth contrasting with the string encoding in <a href="/courses/pe/lessons/pe-imports">the PE import directory</a>, where names are NUL-terminated, or <a href="/courses/coff/lessons/coff-symbol-table">a COFF symbol name</a>, which is 8 bytes with a length in a spare field and where longer names go in the string table. <strong>WebAssembly's data segments are the only place in the format with a genuinely arbitrary byte string, and they are length-prefixed rather than terminated</strong> &mdash; which is the right choice, because a length prefix permits embedded NULs and a terminator does not.</p>
                <h3>The datacount section</h3>
                <p>Here is the whole of it, in a module with one data segment:</p>
                <div class="hex-dump">
                    <pre>  0c 01 00 00 00
    |  |  |
    |  |  +-- the count: ONE data segment follows, later
    |  +----- payload is one byte
    +-------- id 0x0c = datacount

  and the section it is describing, which comes LAST:
  0b 01 00 41 00 0b 04 61 62 63 64
</pre>
                </div>
                <p>Four bytes carrying one number, and that number is the segment count of a section that has not been read yet. The ordering constraint is the whole design: <strong>datacount is section 12, and it must appear between the element section (9) and the code section (10)</strong>, so it is the one place where a section's position is not simply ascending by id. The <a href="/courses/wasm/lessons/wasm-sections">section ordering</a> concept covers why the ids ascend; this is the documented exception, and it exists precisely because the code section has to come before the data section while also being checkable against it.</p>
                <p>And a real object confirms it. The <code>simple.o</code> sample from this course has a data section and wabt reports it:</p>
                <div class="hex-dump">
                    <pre>  $ wasm-objdump -x simple.o | grep -A1 DataCount
  DataCount:
   - data count: 1
</pre>
                </div>
                <p>One number, and the validator uses it to check every <code>memory.init</code> and <code>data.drop</code> in the code section. Without it, <code>memory.init 3</code> in a module with one data segment would have to be either trusted or deferred, and both are worse: trusting it lets a validated module trap at run time on an index the validator was supposed to have caught, and deferring means reading the data section before the code section, which the format's ordering forbids.</p>
                <div class="callout callout-warn">
                    <strong>The subtlety: datacount is optional, and omitting it is not automatically an error.</strong> It is required when the code section contains a bulk-memory instruction that names a data segment. A module with a data section and no such instruction may legitimately omit it &mdash; so a reader must not treat its absence as "zero data segments", and must not treat its absence as an error without checking whether the code section actually needs it. <strong>A reader that requires datacount unconditionally will reject valid modules; a reader that treats it as optional unconditionally will fail to catch an out-of-range index.</strong> The correct rule is conditional, and it is the kind of rule that has to be stated explicitly because there is no way to infer it from the bytes of any one section. This is the same shape as the limits flags in <a href="/courses/wasm/lessons/wasm-tables-memories">the memory section</a>: a bit that changes what is required, where getting the condition wrong produces a silent misreading rather than an error.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Validating a <code>memory.init</code>, which is the operation datacount exists to make possible, and it is a nice illustration of a general principle about validation order:</p>
                <div class="formula">
validate the code section, with `data_count` read from datacount:

  for each instruction:
    0xfc 0x08 &lt;segidx> 0x00     memory.init
        if datacount is ABSENT: reject
            the code names a data segment, so the forward
            declaration was required and is missing
        if segidx >= data_count: reject
            a module with 1 data segment cannot init segment 3
        # and only NOW is a data_count of 0 meaningful:
        # it means "no segments", so any memory.init is invalid

    0xfc 0x09 &lt;segidx>         data.drop
        same check, same datacount

  and for ELEMENT segments the same problem exists, which is why
  the element section needs no count section: its segments are
  described entirely by their own flags byte and count, and the
  table.init instruction is checked against a count that is
  already available in the section the instruction's own ordering
  permits.
</div>
                <p>Two things there are worth pulling apart. The first is that <strong>datacount gives the validator the number without giving it the content</strong> &mdash; it can bound-check an index against a count it already holds, and only read the data section later when it actually needs the bytes. That is what makes single-pass validation possible, and it is why the section is a count and not a copy of the data section's header.</p>
                <p>The second is more interesting and slightly awkward: <strong>the element section needs no equivalent, and the reason is a subtlety in the ordering rules.</strong> <code>table.init</code> names an element segment, and the element section (9) comes <em>before</em> the code section (10), so a validator reading in order has already read the element section and knows the count. The data section (11) comes <em>after</em> the code section, so the same validator has not. <strong>Datacount is a workaround for an asymmetry in the section ordering, and it exists only on the side that needed it.</strong></p>
                <p>That is worth sitting with, because it shows a format being patched in the least invasive way rather than restructured. The alternative would have been to move the data section before the code section, which would have broken every existing module, or to have the validator make two passes, which costs more than four bytes for everyone. <strong>Datacount is four bytes paid by the producer to avoid two passes by the consumer</strong> &mdash; and it is a good trade precisely because almost every module either needs it or is not much hurt by the four bytes.</p>
                <p>The last piece is what a passive data segment is <em>for</em>, and it is the same pattern as a passive element segment with a different payoff. A passive segment's bytes live in the module, not in a memory, until the module runs <code>memory.init</code> to copy them somewhere it chose. <strong>That is how a program gets read-only constant data into writable memory</strong>, which is a real problem: WebAssembly memories are writable, and a program that wants a large table of constants has to copy them in at start-up, because the data section can only write into a memory at instantiation. A native <a href="/courses/elf/lessons/section-header-table">ELF</a> or <a href="/courses/pe/lessons/pe-section-table">PE</a> image maps a read-only section straight into memory with page protections set by the loader, and needs no copy at all. WebAssembly has no page protection, so it has to copy &mdash; and the passive form is how that copy is expressed without paying for it in every module that does not need it.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -x data0.wasm | sed -n '/^Data/,$p'
$ wasm-objdump -x simple.o | sed -n '/DataCount/,+1p'</code></pre>
                <ul>
                    <li><strong>Produce all three forms and confirm each is a distinct section.</strong> The <code>data0.wasm</code>, <code>data1.wasm</code> and <code>data2.wasm</code> samples are in the course assets. Dump all three, confirm the flags byte differs in every one, and note that forms 0 and 2 are one byte apart. <strong>Three small files and one observation about how little separates an encoding from its sibling.</strong></li>
                    <li><strong>Find where the data section stops being a section.</strong> Change the size byte in form 0 from <code>04</code> to <code>05</code> and see what <code>wasm-validate</code> says. Then to <code>03</code>. <strong>One byte, and the error should name the segment</strong> &mdash; read the message and note that it is a validation error rather than a truncation, which is what a counted blob buys you over a terminated one.</li>
                    <li><strong>Embed a NUL and prove the length prefix is why it works.</strong> Put a <code>00</code> in the middle of a data segment's bytes and confirm it round-trips. Then compare with how a COFF symbol name or a PE import name would have handled the same byte. <strong>Length-prefixed versus NUL-terminated is one of the most consequential small choices in any format, and this is where you can see the difference cost something.</strong></li>
                    <li><strong>Remove the datacount section from a module that needs it.</strong> Hand-edit <code>simple.o</code> to drop section 12, then re-validate. The failure message should tell you the code section needs a data count. <strong>Then add a datacount that disagrees with the data section and confirm which one the validator believes</strong> &mdash; the answer is the datacount, which is a genuinely surprising thing to observe.</li>
                    <li><strong>Make datacount optional in your reader and test both branches.</strong> A module with a data section and no bulk-memory instruction should validate without datacount; one with <code>memory.init</code> should not. <strong>Those two cases are the entire rule, and writing both tests is how you find out whether your reader's condition is the right one or an approximation of it.</strong></li>
                    <li><strong>Compile a C file and read its data section size.</strong> Take something with a large constant table &mdash; a lookup table, a font, a string table &mdash; and look at the data section's size against the module's total. Then compile the same file with <code>-O2</code> and compare. <strong>The gap between the two is what a compiler's constant folding removes from a section that has no compression of its own</strong>, and it is the clearest picture of why the format chose raw bytes over a compressed representation.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a module has two data segments, both passive, and its code section contains no bulk-memory instructions. It has no datacount section. Is the module valid? And separately: what does a reader that requires datacount unconditionally do to a module like this, and why is that the wrong answer?</p>
                <div class="quiz" id="quiz-wasm-data-1">
                    <button class="quiz-option" data-correct="true" data-explain="The module is valid, and the reason is that datacount exists for a specific consumer rather than as a description of the data section. Its only job is to let the validator bound-check data segment indices used by memory.init and data.drop in the code section, and this module's code section names no data segments, so there is nothing to check and the count is not needed. Requiring it unconditionally is wrong for two separate reasons, and both matter. First, correctness: a reader that rejects this module is rejecting a legal one, and a format with a mandatory redundant field is a format every producer has to fill with a number nobody reads. Second, and more subtly, implementation: if the reader treats the absence as zero data segments, it will then reject the two passive segments as out of range, so a single wrong assumption about an optional section produces a cascade. The general rule is that an optional field is optional because something conditionally depends on it, and the condition has to be evaluated against the thing that depends on it rather than assumed either way. That is the same shape as the limits flags in the memory section, where a bit that is not tested produces a silent misreading, and the discipline is identical: find the consumer, and check its actual requirements." onclick="checkQuiz('quiz-wasm-data-1', this)">The module is valid: datacount is only required when the code section names a data segment, and this one does not. A reader that requires it unconditionally rejects a legal module, and a reader that treats its absence as zero segments will then wrongly reject the two passive segments</button>
                    <button class="quiz-option" data-correct="false" data-explain="The module is not valid in the reading this answer takes, but that is the conclusion the question is testing rather than a fact about datacount. The section is a forward declaration, and a forward declaration is only needed by something that will read the thing being declared. A code section with no memory.init and no data.drop has no reference to bound-check, so the count has no consumer and its absence is unobservable. If datacount were mandatory whenever a data section existed, the four bytes would be pure overhead in every module that never uses bulk memory, which is the majority of modules. So the correct answer is that the module is valid and the requirement is conditional." onclick="checkQuiz('quiz-wasm-data-1', this)">The module is invalid, because a data section exists and datacount must describe it; a reader that skips the check will accept a module whose memory.init names a segment that does not exist</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a validator. It accepts every module with a data section, including ones whose code section contains <code>memory.init 5</code> when only one data segment exists. <code>wasm-validate</code> rejects those. Your validator's data section reader is correct &mdash; it finds all the segments and their bytes. What is missing, what is the smallest correct change, and why does your validator currently accept a module that will trap at run time?</p>
                <div class="quiz" id="quiz-wasm-data-2">
                    <button class="quiz-option" data-correct="true" data-explain="The diagnosis follows directly from what your validator does not do rather than from what it does wrong, and your data section reader being correct is the clue: the segments are found, the bug is that nothing consults the count when it checks the instructions. The smallest correct change is to read the datacount section while walking the section list, store it as an optional, and then in the code section's memory.init and data.drop handling require it to be present and require the index to be below it. Present is a real requirement, not a formality: a module naming a data segment without declaring a count is telling the validator it did not supply the information needed to check the reference, and accepting it is accepting a module whose soundness the validator cannot vouch for. The reason this matters more than a normal validation bug is the failure mode. A module that passes validation but traps on its first memory.init has defeated the entire premise of the format, which is that a validated module cannot be surprised by its own data. A trap in validated code is a soundness failure, not a robustness one, and the four bytes of datacount are the price of not having that class of bug. The general habit is to ask what a validation pass is for, and to notice when a section exists purely to serve a check you are not performing." onclick="checkQuiz('quiz-wasm-data-2', this)">You are not checking data segment indices in the code section. Read the optional datacount, require it to be present when <code>memory.init</code> or <code>data.drop</code> appears, and bound-check against it. A module that validates and then traps has defeated the format's central guarantee</button>
                    <button class="quiz-option" data-correct="false" data-explain="The prompt says the data section reader is correct, which rules this out. A reader that mis-parsed a data segment would also fail to find the segments and their bytes correctly, and the symptom would be a wrong count or a desynchronised parse rather than a correct parse of everything. There is also no plausible mechanism by which reading a data section twice would leave an index unchecked: the index appears in the code section, and the code section is where a check against the count has to happen. The missing work is a check, not a parse." onclick="checkQuiz('quiz-wasm-data-2', this)">Your validator reads the data section twice, once for the count and once for the bytes, and the second read overwrites the first so the count is lost by the time the code section is checked</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a validation pass exists to make a promise about run-time behaviour. When you find a gap, ask which promise it breaks &mdash; and note that "validated code can still trap" breaks a much stronger promise than "validated code can still misbehave".</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The datacount section is the clearest example in this format of a piece of metadata whose only consumer is a validator, and this collection has a few of those. <a href="/courses/coff/lessons/coff-symbol-table">A COFF section's <code>NumberOfRelocations</code></a> is read by a linker rather than by the code, and <a href="/courses/elf/lessons/section-header-table">an ELF section header's <code>sh_info</code></a> is meaningful only to whichever tool interprets that section. In all three the value describes something the reader cannot see yet, and the tool that will see it has to be trusted to check it. <strong>Datacount is the strictest of the three, because the specification requires it exactly when a later section makes a claim the earlier one has to bound.</strong></p>
                <p>The counted-blob encoding of a data segment connects to the way every other format in this collection stores a string table or a resource blob. <a href="/courses/coff/lessons/coff-string-table">A COFF string table</a> is a length-prefixed pool shared by every name in the file. <a href="/courses/pe/lessons/pe-resources">A PE resource</a> is a tree of offsets, and its data entries are a base-relative offset plus a length &mdash; the same two fields as a data segment, in a different order. <a href="/courses/dwarf/lessons/dwarf-dies">A DWARF <code>.debug_str</code></a> entry is a NUL-terminated string at an offset, so it is the one case here that cannot hold an embedded NUL &mdash; which is a real limitation of that format and the reason the others chose differently.</p>
                <p>And the passive segment's purpose &mdash; getting read-only constants into a writable memory because the format has no page protection &mdash; is the direct consequence of a design decision this course has met in several places. WebAssembly memories have no execute, read or write permissions, unlike <a href="/courses/elf/lessons/program-header-table">an ELF <code>PT_GNU_RELRO</code> segment</a> or a PE section's <code>VirtualProtect</code> flags. That simplicity is what makes a WebAssembly sandbox small enough to implement correctly in a browser tab, and it is also why the data section has to copy instead of map, and why <a href="/courses/wasm/lessons/wasm-tables-memories">a memory's optional maximum</a> has to be enforced by the host rather than by the hardware.</p>
                <p>That completes the core format. Every section has now been covered: the framing, the eight declaration and data sections, the code section, the instruction encoding, and the one section that exists only for validation. What is left is what happens <em>before</em> a module is a module &mdash; the object files a compiler emits, the <code>linking</code> and <code>reloc</code> sections that live in custom sections the core specification does not define, and the 5-byte LEB128 that a producer pads its section sizes to. That is the final concept.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-elements">Previous: The Element Section</a></span>
                <span><a href="/courses/wasm/lessons/wasm-objects">Next: Objects, Linking and Relocations</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
