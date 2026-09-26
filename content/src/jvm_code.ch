// JVM Course — Module 2: Members and Code
// Concept: the Code attribute — max_stack, max_locals, the instruction array,
// and the attributes a method carries inside its own body.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_code() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Code Attribute — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>The Code Attribute</h1>
            <div class="lesson-meta">21 min &middot; Module 2: Members and Code &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything so far has been metadata: names, types, flags, versions. The <code>Code</code> attribute is the first place a class file contains something a machine executes, and it is structured in a way that exists for one reason &mdash; <strong>to let a virtual machine allocate a frame before it runs a single instruction.</strong></p>
                <p>That is the whole design brief. The JVM is allowed to interpret, to compile to machine code, or to do nothing at all until a method is hot. All three need the same thing up front: <strong>a frame of a known size.</strong> So the file states the size, twice, in two fields that are not derivable from the code and cannot be discovered by reading it cheaply.</p>
                <p>That is why <code>max_stack</code> and <code>max_locals</code> exist. They are not descriptions of what the code does; they are <em>promises about the worst case</em>, made by the compiler, checked by the verifier, and used by the runtime to size a frame without executing anything. <strong>Getting either wrong is not a subtle bug: it is memory corruption, or a verifier rejection.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Four fields, in this order, and then the code and its table:</p>
                <div class="formula">
Code attribute:
    u2 max_stack               worst-case operand stack depth
    u2 max_locals              worst-case local variable slots
    u4 code_length             bytes of code that follow
    u1 code[code_length]       the instruction stream
    u2 exception_table_length
    exception_table[that many] each entry is FOUR u2s
    u2 attributes_count
    attributes                 nested, same shape as everywhere else
</div>
                <p>Two things make this attribute different from everything else in the format, and both are consequences of it being the only part that runs.</p>
                <p><strong>It is the only place with a variable-length byte array that is not a table of records.</strong> The instructions are not self-describing in the way an attribute is; they are a stream, and <code>code_length</code> is what delimits them. A reader cannot skip a method's code by looking at a tag &mdash; it must either decode the instructions or trust the length. <strong>Compare a <a href="/courses/elf/lessons/relocation-entries">COFF relocation table</a>, where every entry is fixed-width and skippable, or <a href="/courses/wasm/lessons/wasm-instructions">a WebAssembly instruction stream</a>, where the same problem appears and is solved the same way, with a declared length.</strong></p>
                <p>And <strong>it nests.</strong> A method's attributes live inside its <code>Code</code> attribute, not beside it, because they describe the body rather than the method. <code>LineNumberTable</code> maps code offsets to source lines, and that is meaningless without the code. So the <code>Code</code> attribute ends with its own attribute list, and a reader that has just walked a method's attributes has to go one level deeper before it has finished the method.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The smallest complete <code>Code</code> attribute in this course's samples &mdash; a default constructor, five bytes of instructions &mdash; read from the file:</p>
                <div class="hex-dump">
                    <pre>  Code attribute, 29 bytes total, at 0x013f:

    u2 max_stack            = 1
    u2 max_locals           = 1
    u4 code_length          = 5
    u1 code[5]              = 2a b7 00 01 b1
    u2 exception_table_len  = 0
    u2 attributes_count     = 1
       attribute: LineNumberTable, 6 bytes
    u2 code_length? no -- the attribute ended, 0x015c

  the five instructions:
    2a          aload_0       push local 0, which is this
    b7 00 01    invokespecial #1  call java/lang/Object."&lt;init&gt;":()V
    b1          return
</pre>
                </div>
                <p>Every field accounted for: 2 + 2 + 4 + 5 + 2 + 2 = 17 bytes of the 29, and the remaining 12 are the nested <code>LineNumberTable</code> attribute's own 6-byte header plus its 6 bytes of body. <strong>The instruction stream is five bytes and the frame declaration is eight.</strong> That ratio is worth noticing: for a trivial method, the format spends more space declaring the frame than encoding the work.</p>
                <p>Now <code>max_locals</code> in practice, across the methods of a real class. The previous concept established that it counts <code>this</code> plus the parameters; this is what happens when a method has locals of its own:</p>
                <div class="hex-dump">
                    <pre>  method       max_stack  max_locals  code_length
  &lt;init&gt;          1          1           5
  go             0          1           1     empty body
  takes          0          2           1     takes(Object): this + o
  args           0          7           1     (IJLjava/lang/String;[ILjava/lang/Object;)V
  ret            1          1           2
  manyRet        2          1           2
  wide          14         2           70    12 int locals summed

  the wide method is the interesting one: 12 declared locals, and
  max_locals is only 2, because this is a STATIC method whose one
  parameter is an int. The locals live ABOVE that mark, in slots the
  header does not have to describe.
</pre>
                </div>
                <div class="callout callout-warn">
                    <strong>So <code>max_locals</code> is a lower bound, not a description.</strong> In the <code>wide</code> method above, twelve locals are live and <code>max_locals</code> says 2. That is not a bug and not a slack field: <strong>the locals are numbered from the top of the declared parameter area downwards, or equivalently the parameter area is at the bottom and the body's locals start above it</strong> &mdash; and the actual frame is sized by the verifier's own analysis, with <code>max_locals</code> used only as the starting point for parameters. A reader that treats <code>max_locals</code> as "how many locals this method has" is wrong on any method with body locals, and wrong in the direction that looks safe, because the real number is larger. The generated class with 300 live locals makes the point at the other extreme: <code>max_locals</code> is 303 there, so the field is neither a tight bound nor a constant &mdash; <strong>it is whatever the compiler computed, and the only way to know is to read it.</strong>
                </div>
                <h3>max_stack, and why the runtime needs it</h3>
                <p><code>max_stack</code> is the deepest the operand stack ever gets. Two of the values above are worth reading together: the constructor has <code>max_stack = 1</code> for its <code>aload_0</code>, and <code>manyRet</code> has <code>max_stack = 2</code> because returning a <code>long</code> pushes two slots onto the stack for the return value. <strong>The same 64-bit rule from the previous concept, showing up a third time in the same format</strong> &mdash; a <code>long</code> is two slots in the pool, two in the frame, and two on the stack, and all three come from the same decision.</p>
                <p>Why the runtime needs the number at all, given that it could compute it: <strong>computing it requires decoding every instruction.</strong> A JIT that wanted to know the frame size before starting would have to walk the whole method, and an interpreter that wanted to allocate a frame per call would pay that on every call. Stating it turns an O(code length) analysis into a single field read. <strong>And because the verifier checks the field against the code, a wrong value is rejected at load time rather than corrupting a frame at run time</strong> &mdash; which is the whole safety argument for putting the number in the file.</p>
                <h3>The nested attributes</h3>
                <p>Every <code>Code</code> attribute in this course's 22 samples carries a <code>LineNumberTable</code> &mdash; all 65 of them, without exception, because <code>javac</code> emits debug information by default. That is itself a finding: <strong>the default class file is larger for being debuggable</strong>, and the same method without it is smaller by the size of that table.</p>
                <div class="formula">
<pre>LineNumberTable, nested inside Code:
    u2 line_number_table_length
    then that many pairs of:
        u2 start_pc        an OFFSET into the code array
        u2 line_number     a source line

  and note the offset base: start_pc is measured from the FIRST BYTE
  of the instruction array, not from the start of the Code attribute
  and not from the start of the method.
</pre>
                </div>
                <p>And <code>start_pc</code> is an <strong>absolute code offset</strong>, not a branch offset. That distinction is the next concept's whole subject and it is worth flagging here, because the format contains both conventions within one attribute and nothing marks which is which. A <code>LineNumberTable</code> entry says &ldquo;offset 10&rdquo; and means exactly the tenth byte of the code. A branch instruction says &ldquo;offset 10&rdquo; and means ten bytes <em>past the branch's own opcode</em>. <strong>Two different meanings for the same two-byte field in the same structure, and the only way to tell them apart is to know which table you are in.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Walking a method's <code>Code</code> attribute to its end, which is the discipline that catches everything in this format:</p>
                <div class="formula">
walk_code(body_at, body_end):

    max_stack   = u2()
    max_locals  = u2()
    code_length = u4()
    code        = read(code_length)      # trusted for LENGTH, not content

    # the code is a byte stream, so a reader that wants to know where
    # it ended must either decode it or use code_length. A reader that
    # both decodes it AND checks the position against code_length is
    # the only one that can catch its own desync.
    assert decode_and_walk(code).position == code_length

    etl = u2()
    for _ in range(etl):
        start_pc, end_pc, handler_pc, catch_type = u2(), u2(), u2(), u2()
        # all FOUR are absolute code offsets. `to` is EXCLUSIVE.

    assert pos == body_end, "the Code attribute's declared length and
                              what we just read disagree"
</div>
                <p>That last assertion is the one that matters, and it is a two-field check: <strong>the attribute's own <code>attribute_length</code> has to agree with the sum of what you just read.</strong> The format gives you two independent statements about how big a method's code is &mdash; <code>code_length</code> inside the attribute and <code>attribute_length</code> around it &mdash; and a reader that checks one against the other catches a desync that would otherwise be silent.</p>
                <p>That double statement is a real safety net and it is worth seeing why it is there. <code>code_length</code> says how many bytes of instructions follow; <code>attribute_length</code> says how many bytes the whole attribute occupies. They have to differ by a fixed, computable amount &mdash; the eight bytes of <code>max_stack</code>, <code>max_locals</code> and <code>code_length</code>, plus two for the exception table count, plus two for the attributes count, plus the exception table and the nested attributes. <strong>So the difference between the two numbers is a checksum over the structure you just walked</strong>, and a reader that computes it has verified the whole thing without knowing anything about instructions.</p>
                <p>It is the same idea as the end-of-file assertion in the <a href="/courses/jvm/lessons/jvm-header">header concept</a>, one level down. The file's total length checks the walk; a <code>Code</code> attribute's declared length checks the method walk. <strong>A format with nested length-delimited records gives you a checksum at every level, and the discipline is to use it at every level</strong> &mdash; because a reader that only checks the outermost one will happily report a perfectly plausible method with a corrupted instruction stream in the middle of it.</p>
                <p>And the reason this matters more here than anywhere else in the format is that the instruction stream is the one part a reader cannot cheaply skip. An attribute can be skipped by its length without understanding it; a pool entry can be skipped by its tag. <strong>Instructions cannot be skipped at all</strong>, because there is no tag that says how long the next one is &mdash; a reader that does not know an opcode cannot know its width. So the length field is the only thing standing between a desynchronised reader and the rest of the file, and it is the field a hand-rolled decoder is most likely to trust rather than check.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -c -v -p out/Hello.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Hello.class</code></pre>
                <ul>
                    <li><strong>Walk the five-byte constructor by hand.</strong> Eight bytes of header, five of code, two for the exception count, two for the attribute count, then the nested attribute's own header and body. <strong>Add it up and check you land on the attribute's declared length of 29</strong> &mdash; and notice that 17 of those 29 bytes are not instructions.</li>
                    <li><strong>Predict <code>max_stack</code> and <code>max_locals</code> for four methods before looking.</strong> An empty static method, one returning an <code>int</code>, one returning a <code>long</code>, one taking three parameters and returning nothing. <strong>Then check, and expect to be wrong about exactly one of them</strong> &mdash; the <code>long</code> return, for the two-slot reason.</li>
                    <li><strong>Break the two-field check and watch it work.</strong> Change your decoder so it reads the exception table count one byte early, and add the assertion from this concept. Run it on a method with a non-empty exception table. <strong>The assertion fires and names the attribute</strong>, which is a much better error than the wrong instructions you would otherwise report.</li>
                    <li><strong>Find a method where <code>max_locals</code> exceeds the parameter count.</strong> Any method with body locals will do, and the generated 300-local class is the extreme. <strong>Compare the declared parameters to the field and work out where the rest of the frame comes from</strong> &mdash; that gap is the verifier's business, and it is the boundary this concept draws.</li>
                    <li><strong>Count what the debug information costs.</strong> Compile the same class with and without <code>-g:none</code> and compare file sizes and the number of nested attributes. <strong>All 65 <code>Code</code> attributes in this course's samples carry a <code>LineNumberTable</code> by default</strong>, and seeing what that is worth in bytes makes the nesting feel less like free.</li>
                    <li><strong>Read a <code>LineNumberTable</code> and check its offset base.</strong> Find an entry with a <code>start_pc</code>, then look at the instruction at that offset in the code array. <strong>Confirm the offset is counted from the first instruction byte, not from the attribute</strong> &mdash; and then remember it, because the next concept shows a table in the same attribute where the same-looking number means something else entirely.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a <code>Code</code> attribute has <code>max_stack = 3</code>, <code>max_locals = 4</code>, <code>code_length = 40</code>, an empty exception table, and one nested attribute of 8 bytes. How long is the whole <code>Code</code> attribute, and what would a reader that trusted <code>code_length</code> to find the end of the method get wrong?</p>
                <div class="quiz" id="quiz-jvm-code-1">
                    <button class="quiz-option" data-correct="true" data-explain="Two lengths, both needed, and adding them is the whole calculation. The declared attribute_length covers the two-byte max_stack, the two-byte max_locals, the four-byte code_length field, the code itself, the two-byte exception table count with no entries, the two-byte attributes count, and the nested attribute's own six-byte header plus its eight-byte body. That is 2 + 2 + 4 + 40 + 2 + 2 + 6 + 8, which is 66. A reader that treated code_length as the method's extent would stop 40 bytes in, in the middle of the instructions, and would then read the exception table count out of the middle of a method body. Since that count is a two-byte field read from arbitrary instruction bytes, it would almost always be a plausible small number, and the reader would carry on from the wrong place for the rest of the method. The reason this is dangerous rather than merely wrong is that code_length is the one field that genuinely does say how long the instructions are, so trusting it is not unreasonable. It just does not say how long the attribute is, and those two numbers differ by twenty-six bytes here, all of which have to be walked." onclick="checkQuiz('quiz-jvm-code-1', this)">66 bytes: 2 for <code>max_stack</code>, 2 for <code>max_locals</code>, 4 for <code>code_length</code>, 40 of code, 2 for the empty exception count, 2 for the attributes count, and 14 for the nested attribute's header and body. A reader trusting <code>code_length</code> would stop inside the instructions and read the exception table count out of the middle of the method body</button>
                    <button class="quiz-option" data-correct="false" data-explain="The total is right and the failure it would produce is right too, but the arithmetic as stated is a coincidence rather than the structure, and the structure is what generalises. The nested attribute contributes 6 bytes of header because every attribute is a two-byte name index plus a four-byte length. The exception table contributes nothing beyond its two-byte count because it is empty, and the attributes count is 2 because the format always states a count even when the answer is one. Every one of those is a fixed per-structure cost that a reader must account for, and a reader that adds only the obvious terms will be wrong on any method whose exception table is not empty." onclick="checkQuiz('quiz-jvm-code-1', this)">48 bytes: 2 plus 2 plus 4 for the three header fields, 40 of code, and nothing else, since the exception table is empty and the nested attribute is counted separately. A reader trusting <code>code_length</code> would land at exactly the right place but read the wrong field</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your class file reader reports correct method names, correct descriptors and correct <code>max_stack</code> and <code>max_locals</code> for all 400 methods in a large dependency. The instructions it reports for about forty of them are nonsense, and the methods themselves are otherwise indistinguishable from the rest. Your reader trusts <code>code_length</code> to find where a method's code ends. The affected methods are exactly the ones with a non-empty exception table. Nothing errors. What is the defect, what does trusting <code>code_length</code> actually cost here, and what single check would have caught it on the first method you read?</p>
                <div class="quiz" id="quiz-jvm-code-2">
                    <button class="quiz-option" data-correct="true" data-explain="The correlation is exact and it names the bug. code_length is the length of the instruction array and nothing else, so a reader using it to find the end of the Code attribute stops immediately after the code and reads the exception table count out of whatever bytes follow. For a method with no exception table that read happens to be the correct field, because the count really is next, which is why the bug is invisible on three hundred and sixty methods. For a method with a non-empty table the reader then miscounts the exception table and desynchronises, and because the exception table is the last variable-length thing before the nested attributes, the damage lands in the attribute list and then in the next method. The cost of trusting code_length is that it silently conflates two different lengths that differ by a computable, fixed amount, so the check is to compare code_length against the enclosing attribute_length: the difference must equal eight plus two plus the exception table's size plus the nested attributes' total. That check needs no knowledge of instructions, runs in a few lines, and would have failed on the first method in the file. The deeper lesson is that a field named for one thing and used for another is the most expensive kind of bug in a length-delimited format, because the name actively misleads the person writing the reader." onclick="checkQuiz('quiz-jvm-code-2', this)">The reader uses <code>code_length</code> to find the end of the <code>Code</code> attribute rather than the end of the instructions, so it reads the exception table count from the wrong place and desynchronises &mdash; harmless when the table is empty, wrong exactly when it is not. Compare <code>code_length</code> against the enclosing <code>attribute_length</code>: the difference must be a fixed, computable sum</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real risk and worth ruling out, but the evidence is cleaner than that. If the reader were not walking the exception table at all, the failures would not correlate with methods that have one. A reader that ignores the exception table entirely would produce correct results for every method whose table is empty, because there is nothing to get wrong, and wrong results only for the ones that have a table. That is exactly the observed pattern, which means the reader is attempting the table and getting its length wrong, not skipping it. The distinction matters because the two bugs have different fixes and different symptoms in a partial failure." onclick="checkQuiz('quiz-jvm-code-2', this)">The reader is decoding instructions it does not recognise, and the affected methods are simply the ones that use opcodes its table lacks, which the non-empty exception tables have nothing to do with</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a length field named for one thing and used for another is the most expensive bug in a length-delimited format, because the name misleads the person writing the reader. And when a bug correlates perfectly with an optional structure, the missing or wrong handling is in that structure's branch.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Stating the worst case so a runtime can allocate before executing is not unique to the JVM, and comparing the three ways of doing it shows why this one is shaped the way it is. An <a href="/courses/elf/lessons/program-header-table">ELF program header</a> declares <code>p_memsz</code>, a static size the loader can trust without reading a byte of code. A <a href="/courses/pe/lessons/pe-section-table">PE section header</a> declares <code>VirtualSize</code> against <code>SizeOfRawData</code>, covering the same ground with two fields. <strong>The JVM needs something none of those can supply, because the JVM compiles the method at run time</strong> &mdash; the frame is not a static region carved out of the image, it is built per call, so the size has to be in the file rather than implied by a segment boundary.</p>
                <p>The instruction stream's framing is the same problem <a href="/courses/wasm/lessons/wasm-instructions">WebAssembly</a> has, and the two solutions are worth comparing directly. Both wrap a variable-width byte stream in a declared length. Both forbid a reader from skipping instructions it does not understand, because there is no per-instruction width field. And both therefore have the property that <strong>a single unknown opcode makes the rest of the method unreadable</strong> &mdash; a WebAssembly module with an unknown opcode is rejected wholesale, and a class file with one is rejected by the verifier. <strong>Neither format has an escape hatch, and both live with it by making the opcode space closed and versioned.</strong> That is the opposite of the class file's attribute design, which is open, and the contrast is the interesting part: a format can be closed where it executes and open where it describes.</p>
                <p>The nesting is a small instance of a larger pattern. <a href="/courses/coff/lessons/coff-section-table">COFF puts relocations in their own section</a> rather than inside the code they patch; <a href="/courses/elf/lessons/section-header-table">DWARF puts line numbers in their own section</a> rather than beside the code. The JVM puts them <em>inside</em> the <code>Code</code> attribute, and the reason is a coupling the other two avoid: a line number is a code offset, and a relocation is an index into a symbol table, but a line number is meaningless unless you already have the code it indexes. <strong>Nesting is chosen where the child references the parent's content, and kept separate where it references something else.</strong></p>
                <p>And the <code>LineNumberTable</code>'s absolute offsets set up the next concept directly. This attribute says &ldquo;offset 10&rdquo; and means the tenth byte. <a href="/courses/jvm/lessons/jvm-branches">The next one</a> shows an offset field in the same structure where the same number means something else &mdash; and it is the sharpest single trap in the format.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-members">Previous: Fields, Methods and Descriptors</a></span>
                <span><a href="/courses/jvm/lessons/jvm-branches">Next: Two Offset Conventions</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
