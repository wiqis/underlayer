// WebAssembly Course — Module 4: Data Placement
// Concept: the element section — eight encodings for one job, and the flag byte
// that is the most overloaded field in the format.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_elements() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Element Section — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>The Element Section</h1>
            <div class="lesson-meta">24 min &middot; Module 4: Data Placement &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The element section fills tables. That is its entire job, and it is a small enough job that you would expect a small encoding. Instead it has <strong>eight segment forms</strong>, and understanding why is the most useful thing this concept can teach &mdash; because the answer is that each form was added to solve a problem the previous forms could not, and none of them were removed.</p>
                <p>A table holds function references, and <a href="/courses/wasm/lessons/wasm-tables-memories">the table section</a> told you how big it is. The element section says what goes in it, and there are three genuinely different questions to answer about that:</p>
                <ul>
                    <li><strong>Is the segment active or passive?</strong> Active means "copy these into the table when the module is instantiated". Passive means "hold these, and let the module copy them in itself later with <code>table.init</code>". The second is a real capability: it lets a module build a jump table at run time, which an active-only format cannot express.</li>
                    <li><strong>Which table, and where in it?</strong> Most segments go into table 0 at an offset computed by a constant expression. A segment may name a different table &mdash; needed as soon as a module has more than one.</li>
                    <li><strong>Are the elements function indices or expressions?</strong> A plain list of <code>funcidx</code> is compact and covers almost everything. But a table may hold <code>externref</code> values the host supplied, which have no function index at all, and may hold <code>null</code>, which is not a function either. So a general form is needed that can compute an element from an expression.</li>
                </ul>
                <p>Two binary choices would give four forms. There are eight, because the original design committed to <strong>the shortest possible encoding for the most common case</strong> and then added forms for the other combinations &mdash; including a <em>declarative</em> mode that has no analogue in the other two dimensions at all.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The whole section is a vector of segments, and each segment starts with a flags byte that says which of the eight shapes follows:</p>
                <div class="formula">
element section:
    count                       how many segments follow

segment:
    flags                       ONE byte, 0 to 7
    ...then the fields that flags selects
</div>
                <p>The eight forms, laid out by the two binary dimensions plus the third:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Flags</th><th scope="col">Mode</th><th scope="col">Table</th><th scope="col">Elements</th><th scope="col">Fields after the flag</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>0</code></td><td>active</td><td>implicit 0</td><td>funcidx vector</td><td>offset expr, then a count and that many indices</td></tr>
                        <tr><td><code>1</code></td><td>passive</td><td>&mdash;</td><td>funcidx vector</td><td>elemkind byte, count, indices</td></tr>
                        <tr><td><code>2</code></td><td>active</td><td>explicit</td><td>funcidx vector</td><td>table index, offset expr, elemkind byte, count, indices</td></tr>
                        <tr><td><code>3</code></td><td>declarative</td><td>&mdash;</td><td>funcidx vector</td><td>elemkind byte, count, indices</td></tr>
                        <tr><td><code>4</code></td><td>active</td><td>implicit 0</td><td>expr vector</td><td>offset expr, count, that many expressions</td></tr>
                        <tr><td><code>5</code></td><td>passive</td><td>&mdash;</td><td>expr vector</td><td>reftype byte, count, expressions</td></tr>
                        <tr><td><code>6</code></td><td>active</td><td>explicit</td><td>expr vector</td><td>table index, offset expr, reftype byte, count, expressions</td></tr>
                        <tr><td><code>7</code></td><td>declarative</td><td>&mdash;</td><td>expr vector</td><td>reftype byte, count, expressions</td></tr>
                    </tbody>
                </table>
                <p>Read the table by rows and the pattern is obvious: <strong>forms 0&ndash;3 are the function-index family, 4&ndash;7 are the expression family, and within each family the four modes are in the same order</strong>. Active-implicit, passive, active-explicit, declarative. The numbering is structured, not arbitrary, which is worth knowing because it means the flag value alone tells you the encoding's family and its mode.</p>
                <div class="callout callout-warn">
                    <strong>The <code>0x00</code> elemkind byte is the trap in this section, and it is the most dangerous single byte in the format.</strong> In forms 1, 2 and 3, an <em>elemkind</em> byte appears before the element count, and its only legal value is <code>0x00</code>, meaning "the table element type is <code>funcref</code>". It is not a valtype &mdash; the valtype <code>funcref</code> is <code>0x70</code>, as in forms 5&ndash;7. So the same concept has two different byte encodings in the same section, thirty bytes apart. A reader that expects <code>0x70</code> and gets <code>0x00</code> will not necessarily notice, and a reader that reads the <code>0x00</code> as a count of zero will report <strong>an empty segment for a segment that has three elements in it</strong> &mdash; and then desynchronise, because the three indices it did not read are still in the stream. <strong>Why does the byte exist at all if it is always zero?</strong> Because a later proposal wanted <code>externref</code> there, and the field was reserved rather than omitted. The flag space was extended (forms 4&ndash;7) before the elemkind byte was ever given a second value. A vestigial field kept for symmetry with a future, and the symmetry cost a byte and a reader's sanity.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>One section, five segments, five different flag values, 32 bytes. Here are all of them and all eight forms are verified below:</p>
                <div class="hex-dump">
                    <pre>0028: 05 00 41 00 0b 02 00 01 02 01 41 01 0b 00 01 02
0038: 03 00 01 00 01 00 02 00 01 02 04 41 02 0b 00 00
</pre>
                </div>
                <p>And wabt's own reading of the same bytes, which prints the flag value directly &mdash; so this is a check by a second reader on the exact field the concept is about:</p>
                <div class="hex-dump">
                    <pre>  segment[0] flags=0 table=0 count=2 - init i32=0
    elem[0] = ref.func:0        elem[1] = ref.func:1
  segment[1] flags=2 table=1 count=1 - init i32=1
    elem[1] = ref.func:2
  segment[2] flags=3 table=0 count=1
    elem[1] = ref.func:0
  segment[3] flags=1 table=0 count=2
    elem[1] = ref.func:0        elem[2] = ref.func:1
  segment[4] flags=2 table=4 count=0 - init i32=2
</pre>
                </div>
                <p>Segment 4 is worth a second look: <strong>a table index of 4 and a count of zero.</strong> It is a legal active segment that writes nothing to table 4 at offset 2. It was generated because a <code>(table $e)</code> was declared and an element segment named it, but nothing was put in it. A reader that assumed a non-zero count would be wrong here, and a reader that assumed the table index was small would be suspicious of 4. <strong>Empty is not the same as absent, and this section contains both.</strong></p>
                <h3>Decoding the first segment by hand</h3>
                <p>Four segments in this section are the function-index family, so let me walk all of them from the raw bytes:</p>
                <div class="hex-dump">
                    <pre>  05                count: FIVE segments

  segment 0 -- flags = 0x00, active, table 0, funcidx vector
    00                flags = 0
    41 00 0b          offset: i32.const 0 ; end
    02                TWO elements
    00 01             funcidx 0, funcidx 1

  segment 1 -- flags = 0x02, active, EXPLICIT table, funcidx vector
    02                flags = 2
    01                table index = 1
    41 01 0b          offset: i32.const 1 ; end
    00                ELEMKIND: 0x00 = funcref   &lt;- the trap byte
    01                ONE element
    02                funcidx 2

  segment 2 -- flags = 0x03, declarative, funcidx vector
    03                flags = 3
    00                ELEMKIND: 0x00
    01                ONE element
    00                funcidx 0

  segment 3 -- flags = 0x01, passive, funcidx vector
    01                flags = 1
    00                ELEMKIND: 0x00
    02                TWO elements
    00 01             funcidx 0, funcidx 1
</pre>
                </div>
                <p>Compare segment 1 with segment 3, which are the two that most often trip people up. <strong>Segment 3 is passive and has no offset expression and no table index; segment 1 is active and has both.</strong> A reader that decides "active versus passive" by looking for an offset will be wrong about form 1, where the byte sequence begins with the elemkind and there is no <code>0x41</code> to be found. And <strong>the elemkind byte looks identical in forms 1, 2 and 3</strong>, so a reader that special-cases one of them by position will be wrong about the other two.</p>
                <h3>The four forms wabt will not emit</h3>
                <p>Here is a finding worth having, because it would be easy to write this concept from the specification alone and get the claim backwards. <strong>wabt's writer lowers the expression forms to the function forms.</strong> Writing <code>(elem (i32.const 0) (ref.func $f0) (ref.func $f1))</code> produces <code>flags=0</code>, not <code>flags=4</code>:</p>
                <div class="hex-dump">
                    <pre>  (elem (i32.const 0) (ref.func $f0) (ref.func $f1))
      -> segment[0] flags=0 table=0 count=2 - init i32=0
         (the function-index form, NOT the expression form)

  (elem funcref (item (ref.func $f0)))
      -> segment[0] flags=1 table=0 count=1
         (passive function-index form, NOT flags=5)
</pre>
                </div>
                <p>So forms 4 through 7 cannot be produced with <code>wat2wasm</code>, and a course that claimed to have observed them from a <code>.wat</code> file would be wrong. <strong>They were verified here by hand-assembling the bytes</strong> and confirming that a second, independent implementation accepts them:</p>
                <div class="hex-dump">
                    <pre>  form 4   04 41 00 0b 02 d2 00 0b d2 01 0b
          |   |  |     |  |  |     |
          |   |  |     |  |  +----- ref.func 1 ; end
          |   |  |     |  +-------- ref.func 0 ; end
          |   |  |     +----------- count = 2 expressions
          |   |  +----------------- offset: i32.const 0 ; end
          |   +-------------------- flags = 4
          +------------------------ ACTIVE, table 0, expression vector

  form 5   05 70 01 d2 00 0b        PASSIVE, reftype 0x70, 1 expression
  form 6   06 00 41 00 0b 70 02 d2 00 0b d2 01 0b
                                    ACTIVE, table 0, reftype, 2 expressions
  form 7   07 70 01 d2 00 0b        DECLARATIVE, reftype 0x70, 1 expression
</pre>
                </div>
                <p>Note the contrast that makes the trap concrete: <strong>form 4 has no type byte at all, while form 5 has <code>0x70</code></strong>, and both describe a <code>funcref</code> table. The difference is that form 4 is active into table 0, whose element type the module already declared in the table section, so there is nothing to check &mdash; while a passive or declarative segment has no table to inherit from and must state its own element type. <strong>The type byte appears exactly where the table section cannot supply the information.</strong> That is a design principle, and it predicts which of the eight forms have the byte without anyone having to enumerate them.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Deciding which form to emit, which is the operation every producer actually performs, and the arithmetic behind it:</p>
                <div class="formula">
<pre>
choose_form(table_index, is_active, is_declarative, elements, type_section):

    needs_table_index = (table_index != 0)         # 0 is the common case
    needs_type_byte   = NOT is_active              # an active segment
                                                  # inherits its table's type
    elements_are_plain_funcidx = every element is a
                                  ref.func to a function in this module

    if elements_are_plain_funcidx:
        base = 0                       # forms 0-3
    else:
        base = 4                       # forms 4-7, expression vector

    if is_active:
        form = base + (2 if needs_table_index else 0)
    elif is_declarative:
        form = base + 3
    else:                              # passive
        form = base + 1

    # and the minimum size:
    #   form 0: 1 + offset_expr + 1 + n        (no type byte, no table index)
    #   form 4: 1 + offset_expr + 1 + n*3      (d2 xx 0b per element)
    # so an expression form costs 2 extra bytes PER ELEMENT
</pre>
                </div>
                <p><strong>That last line is the whole economic argument for forms 0&ndash;3, and it is why wabt always uses them.</strong> A <code>ref.func</code> expression encodes as <code>0xd2</code>, a LEB index, and <code>0x0b</code> &mdash; three bytes for a function index that a <code>funcidx</code> vector stores in one. A table of 100 entries is 33 bytes larger in the expression form. Since the function-index forms can express every function reference that a module actually needs, and the expression forms exist only for values that have no function index, <strong>a producer should use forms 0&ndash;3 whenever it can and the expression forms only when it must.</strong> wabt's normalisation is not a limitation; it is the correct choice.</p>
                <p>Now the three modes, and what each one actually buys, because "passive" and "declarative" are the two that puzzle people:</p>
                <ul>
                    <li><strong>Active</strong> means the host does the copying at instantiation. The offset expression is evaluated then, and it may reference <a href="/courses/wasm/lessons/wasm-imports">an imported global</a> &mdash; so a module can be handed a table base by its host. <strong>Nothing in the module's own memory moves at run time.</strong></li>
                    <li><strong>Passive</strong> means the segments sit in the <a href="/courses/wasm/lessons/wasm-data">data section's</a> own storage until the module runs <code>table.init</code> and <code>elem.drop</code>. This is how a module builds a jump table at run time &mdash; the pattern C++ and Rust use for virtual dispatch, where the table is not known until the program's types are. <strong>It is the difference between a table the host sets up and a table the program constructs.</strong></li>
                    <li><strong>Declarative</strong> is the strangest, and it has no run-time effect at all. A declarative segment does not populate a table; it declares that <em>these functions may appear in a table</em>. That is a <em>validation</em> device: a <code>ref.func</code> instruction may only name a function that has been declared somewhere, either by a <code>elem declare</code> segment or by appearing in an active, passive or exported position. <strong>Without it, any function could be smuggled into a table, and a validated module could build a <code>call_indirect</code> target the author never intended</strong> &mdash; which is a control-flow-integrity hole, the same class of problem that <a href="/courses/pe/lessons/pe-base-relocations">control-flow integrity</a> exists to close on native platforms.</li>
                </ul>
                <p>So the eight forms are not eight encodings of one idea. <strong>They are three capabilities, in two element representations, plus a table-index distinction that is an optimisation.</strong> A reader that treats the flags byte as a single enumeration of eight cases is correct, and a reader that understands the decomposition can extend the format correctly when a ninth mode is proposed &mdash; because it will already know which axis the new mode belongs to.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -x elems.wasm | sed -n '/^Elem/,/^Code/p'
$ python3 courses/wasm/assets/samples/wasm_decode.py elems.wasm</code></pre>
                <ul>
                    <li><strong>Produce all five function-index forms from WAT.</strong> Write a module with <code>(elem (i32.const 0) $f0 $f1)</code>, <code>(elem func $f0)</code>, <code>(elem (table $t) (i32.const 1) func $f0)</code>, <code>(elem declare func $f0)</code> and <code>(elem (table $t) (offset (i32.const 0)) funcref)</code> &mdash; an empty one. Read all five back and identify the flags. <strong>Five forms, one section, thirty-two bytes, and wabt prints the flag value so you do not have to infer it.</strong></li>
                    <li><strong>Hand-assemble form 4 and see wabt lower it.</strong> Take the <code>form4.wasm</code> sample and dump it. Then write the same module in WAT with <code>(ref.func)</code> elements and compile it. <strong>The two files differ, and the difference is the entire lesson about expressions versus function indices.</strong></li>
                    <li><strong>Delete the elemkind byte and see what breaks.</strong> Take a module with a form-1 segment and remove the <code>0x00</code>. <code>wasm-validate</code> will reject it &mdash; but write your own reader first and see <em>how</em> it fails. It will read the count from the wrong byte, and either report a wildly wrong element count or desynchronise. <strong>Knowing which of those two happens tells you whether your reader would have been caught by the validator or would have silently produced a wrong table.</strong></li>
                    <li><strong>Build a reader that decodes all eight, and test it on all eight.</strong> The four <code>form*.wasm</code> samples are already in the course assets. Point your reader at each, confirm it identifies the form from the flags byte, and confirm it decodes every field including the type byte where present. <strong>Eight cases, all verifiable, and a reader that handles seven is worse than one that handles none because it fails silently on the eighth.</strong></li>
                    <li><strong>Compile C++ and read the table construction.</strong> Compile a C++ file with a virtual class, look for <code>elem</code> sections, and check whether they are active or passive. With the vtable built at run time you should see passive segments and <code>table.init</code> instructions. <strong>That is a real compiler choosing the mode for a reason, and reading the reason is worth more than reading the encoding.</strong></li>
                    <li><strong>Find a case where the offset uses an imported global.</strong> Write <code>(global $base (import "env" "base") i32)</code> and <code>(elem (global.get $base) $f0)</code>. Confirm the initialiser is a <code>global.get</code> rather than a constant, and reason about what the validator can and cannot check about the resulting table bounds. <strong>It is the clearest demonstration that an active segment's position is chosen by the host, not the module.</strong></li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a segment's bytes are <code>02 01 41 01 0b 00 01 02</code>. What are the flag value, the table, the offset, the element type and the contents? And what would a reader that expected <code>0x70</code> for the element type report?</p>
                <div class="quiz" id="quiz-wasm-elements-1">
                    <button class="quiz-option" data-correct="true" data-explain="Every field is accounted for, and the discipline is in knowing which field the flags byte selects. 0x02 is form 2: active, explicit table index, function-index vector. So 0x01 is the table index, 41 01 0b is the offset expression i32.const 1 followed by end, and then the next byte 0x00 is the elemkind. That 0x00 is the trap, because it is not a valtype: in the elemkind position its only legal value is 0x00, meaning funcref, and the valtype funcref is 0x70. A reader expecting 0x70 would then read 0x01 as the element count, take 0x02 as a function index, and reach the end of the segment with one byte unconsumed -- so it would report one element, function 2, which happens to be right, while its position is one byte past the segment. That coincidence is exactly what makes this bug survive: a one-element segment read with the wrong field boundary lands on the right answer. With three elements it would report the wrong count and desynchronise, and with zero it would report nothing at all. The general habit is that a vestigial field whose only legal value is zero has to be handled explicitly, because a reader that treats it as any other field is reading a count, and a count is where off-by-one errors go to hide." onclick="checkQuiz('quiz-wasm-elements-1', this)">Flags <code>0x02</code>: active, into table 1 at offset 1, element type <code>funcref</code>, one element, function index 2. The elemkind byte is <code>0x00</code>, not <code>0x70</code> &mdash; a reader expecting <code>0x70</code> would misread the count, land one byte off, and here it would coincidentally still report the right element</button>
                    <button class="quiz-option" data-correct="false" data-explain="The flag is decoded correctly, but the element type is not. In the elemkind position the only legal byte is 0x00, and 0x70 is the valtype encoding of funcref used in the expression forms 5 through 7. Reading 0x00 as 0x70 would not report the wrong element type -- it would report an illegal one, because 0x00 is not a valtype anywhere in the format. The correct reading is that this is a form-2 segment, the byte is an elemkind whose value 0x00 abbreviates funcref, and the count and function index that follow are 01 and 02. The distinction between an elemkind byte and a reftype byte is the whole point of the segment being a form 2 rather than a form 6." onclick="checkQuiz('quiz-wasm-elements-1', this)">Flags <code>0x02</code>: active, into table 1 at offset 1, element type <code>externref</code> because the type byte is <code>0x00</code>, one element, function index 2</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a table-initialising runtime. On a module with one passive element segment holding three functions, your runtime copies nothing: the table comes up all null, and the module's first <code>call_indirect</code> traps. The same runtime handles every active segment correctly, and <code>wasm-validate</code> accepts the module. The segment's bytes are <code>01 00 03 00 01 02</code>. What is the defect, and why did it not show up on any of your active-segment tests?</p>
                <div class="quiz" id="quiz-wasm-elements-2">
                    <button class="quiz-option" data-correct="true" data-explain="The bytes decode the defect exactly. 0x01 is form 1: passive, no table, no offset, elemkind byte 0x00, then a count of 03 and function indices 0, 1, 2. A reader that handled passive segments by reading an offset expression and a table index would take the 0x00 elemkind as the start of an expression, find no i32.const, and either reject the segment or skip it. The reason no active-segment test caught it is that the two encodings have nothing in common after the flags byte. An active form-0 segment is flags, offset, count, indices; a passive form-1 is flags, elemkind, count, indices. A reader written to the active shape will parse the passive shape into a plausible structure, and the two shapes differ in exactly one byte's worth of position, which is precisely the amount of error that produces a wrong-but-reasonable answer rather than a crash. And validation cannot help: a passive segment is a perfectly legal thing to declare, and whether anything ever copies it in is a question about the module's instructions, not about the segment. So the correct behaviour for your runtime is to make passive segments available as a source and require an explicit table.init to consume them, and the fix in the reader is to branch on the flags byte for every segment, which is a four-line change and the reason the flag byte is worth having." onclick="checkQuiz('quiz-wasm-elements-2', this)">The reader is decoding the segment with the active-segment shape. Form 1 is passive &mdash; no table index and no offset, just an elemkind byte &mdash; so it read the elemkind as the start of an offset expression. Active tests could not catch it because the two shapes share nothing after the flags byte, and a wrong parse here is plausible rather than a crash</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is worth considering and the evidence argues against it. A wrong element type would be caught at validation, because a passive segment's type must match the table it is later initialised into, and a funcref table cannot take externref elements. More importantly, the symptom you describe is that nothing is copied, not that the wrong values are copied, and a type error would produce the latter: entries present, of the wrong kind, failing on the call rather than on the read. Reading the segment as an active one with an offset expression that starts with 0x00 produces the former, because the whole segment is consumed as something the runtime does not act on." onclick="checkQuiz('quiz-wasm-elements-2', this)">Your reader treats the elemkind byte as a valtype, so the segment's elements are externref rather than funcref, and the type check against the table rejects them</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a field's position or presence depends on a preceding tag, branch on the tag for every value of it. And test the branch, not the happy path &mdash; a reader that handles the most common shape correctly has told you nothing about the other seven.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The element section's growth pattern is a case study in format evolution, and this collection has two other instances to set it against. <a href="/courses/pe/lessons/pe-imports">The PE import directory</a> grew by adding directory entries rather than variants, and <a href="/courses/dwarf/lessons/dwarf-versions">DWARF's version number</a> grew by reserving whole tag ranges per version. WebAssembly's approach &mdash; add a flag value, never remove one, and keep the old encodings valid forever &mdash; is the one that requires an eight-way switch in every reader, and it is the one that makes a modern reader strictly larger than a 2017 one. <strong>The alternative was to break the old encodings, and the format's designers chose file size over reader simplicity.</strong> That is a defensible trade for a format whose files are downloaded once and executed many times, and it is exactly the opposite of what <a href="/courses/coff/lessons/coff-symbol-table">COFF</a> does with its auxiliary records, where the variety is handled by a count rather than by a tag.</p>
                <p>The declarative mode has a direct counterpart in security mechanisms this course has already met. <a href="/courses/pe/lessons/pe-load-config">The PE load config</a> and <a href="/courses/pe/lessons/pe-security-flags">control flow guard</a> exist to stop a module calling through a function pointer it did not author, and the declarative element segment is the same guarantee expressed in four bytes: <em>only these functions may enter a table</em>. A native platform needs a load-time table because addresses are unforgeable in practice; WebAssembly needs a section because indices are trivially forgeable, and says so explicitly.</p>
                <p>The passive mode and the <a href="/courses/wasm/lessons/wasm-data">data section's</a> passive form are the same idea for the two kinds of segment, and both need a <a href="/courses/wasm/lessons/wasm-data">datacount section</a> before the instructions that consume them can be validated. That is the next concept, and it is the last piece of the core format: <strong>a section that exists only to let an earlier section be checked against a later one.</strong></p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-instructions">Previous: Instruction Encoding</a></span>
                <span><a href="/courses/wasm/lessons/wasm-data">Next: The Data Section and DataCount</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
