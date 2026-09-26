// WebAssembly Course — Module 1: The Container
// Concept: LEB128 — the encoding almost every number in the format uses, and the
// signed/unsigned split that produces three different answers for the same two bytes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_leb128() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("LEB128 — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>LEB128</h1>
            <div class="lesson-meta">24 min &middot; Module 1: The Container &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is the statistic that should make this concept worth a page. In a WebAssembly module, <strong>there are exactly two fixed-width integers in the container framing: the four magic bytes and the four version bytes.</strong> Every other number &mdash; every section size, every name length, every count of entries, every index, every memory limit, every instruction operand &mdash; uses the same variable-width encoding. The header and the framing are the exception, not the rule.</p>
                <p>That encoding is LEB128, and it is the single detail that a reader of this format must get exactly right, because the failure is silent in a way that almost nothing else in the format is. A decoder that reads a two-byte LEB128 correctly and a one-byte LEB128 correctly will still be wrong on every negative number, and it will be wrong by an amount that varies with the value.</p>
                <p>The reason is worth stating before the mechanism, because it explains the design. Almost every number in a WebAssembly module is small. Section sizes, entry counts, type indices, local indices &mdash; the overwhelming majority fit in one byte, so a variable-width encoding that spends one byte on the common case and only more when necessary is close to free. A <code>u32</code> field costs four bytes per number forever; a LEB128 costs one. In a module with a thousand instructions, that difference is thousands of bytes.</p>
                <p>And the cost of the optimisation is this: <strong>the encoding no longer has a fixed width, so the reader cannot tell where the next number starts without decoding it.</strong> A fixed-width field is a stride you can jump over. LEB128 is a length you must walk. That is the trade, it is a good trade, and every decoder in the format has to implement it correctly before it can do anything else.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The mechanism, in one picture. A LEB128 is little-endian base 128: seven bits of value per byte, and the high bit says whether more bytes follow.</p>
                <div class="hex-dump">
                    <pre>  byte:   7 6 5 4 3 2 1 0
          +-+-+-+-+-+-+-+-+
          | |  value   0 |
          +-+-+-+-+-+-+-+-+
            ^             ^
            |             +-- bit 0
            +---------------- the high bit: 1 means "another byte follows"

value = (byte0 and 0x7f)
      + (byte1 and 0x7f) &lt;&lt; 7
      + (byte2 and 0x7f) &lt;&lt; 14
      + ...
</pre>
                </div>
                <p>That is the whole unsigned encoding. Two properties are worth holding onto: the bytes are consumed <strong>least-significant group first</strong>, and a <strong>single byte with the high bit clear is a complete value</strong> with no lookahead. The second is why the format has no length prefix for its numbers &mdash; the encoding is self-delimiting, and a reader knows where it ended by looking at the last byte it read.</p>
                <h3>And then there is the signed version</h3>
                <p>Signed LEB128 uses the same seven-bits-per-byte layout and differs in exactly one rule: <strong>the sign of the value comes from the high bit of the <em>last</em> byte, not the low bit.</strong> The decoder takes the value it has assembled and, if that final byte's bit 6 is set, subtracts one more group unit.</p>
                <div class="hex-dump">
                    <pre>the final byte is  b6 b5 b4 b3 b2 b1 b0 | 0
                     |                      |       |
                     |                      |       +-- continuation
                     |                      +---------- bit 6: the SIGN
                     +--------------------------------- the value bits

one-byte signed values, exhaustively:
    00 ->   0      40 ->  -64
    01 ->   1      41 ->  -63
    3f ->  63      7f ->  -1
    40 -> -64      80 -> (continues, so it is not a one-byte value)
</pre>
                </div>
                <p>Read that table and the trap is visible. <code>0x3f</code> is 63 and <code>0x40</code> is &minus;64, with no gap between them &mdash; the range is continuous because 63 is followed immediately by its negation. And <code>0x7f</code> is &minus;1, not 127.</p>
                <div class="callout callout-warn">
                    <strong>The same two bytes, three answers.</strong> <code>0x7f</code> is &minus;1 read as signed LEB128, 127 read as unsigned LEB128, and &mdash; once it has been widened to a 32-bit <code>i32</code> and printed without a sign &mdash; 4294967295. All three are correct readings of two bytes, and <strong>the file contains nothing that distinguishes them.</strong> What tells you which is intended is the field: a <code>i32.const</code> operand is signed, a section size is unsigned. There is no marker in the encoding itself. This is the one place in the WebAssembly format where the same bytes are genuinely ambiguous, and it is why the format uses two different functions for the two cases rather than one function with a flag.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Four real operands, three decoders</h3>
                <p>Take a module with four constants, one of them positive, and read the four immediates out of the code section. The source is:</p>
                <pre><code>(func (export "neg") (param i32) (result i32)
  local.get 0
  i32.const -1
  i32.add)
(func (export "big") (result i32)  i32.const 1000000)
(func (export "minusbig") (result i32)  i32.const -1000000)
(func (export "i64neg") (result i64)  i64.const -1)</code></pre>
                <p>Read the immediates with the decoder shipped with this course, and compare all three decodings side by side:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Source</th><th scope="col">Bytes</th><th scope="col">Signed LEB128 (correct)</th><th scope="col">Unsigned LEB128 (wrong)</th><th scope="col">Widened unsigned (what wabt prints)</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>i32.const -1</code></td><td><code>7f</code></td><td><strong>&minus;1</strong></td><td>127</td><td>4294967295</td></tr>
                        <tr><td><code>i32.const 1000000</code></td><td><code>c0 84 3d</code></td><td><strong>1000000</strong></td><td>1000000</td><td>1000000</td></tr>
                        <tr><td><code>i32.const -1000000</code></td><td><code>c0 fb 42</code></td><td><strong>&minus;1000000</strong></td><td>1097152</td><td>4293967296</td></tr>
                        <tr><td><code>i64.const -1</code></td><td><code>7f</code></td><td><strong>&minus;1</strong></td><td>127</td><td>18446744073709551615</td></tr>
                    </tbody>
                </table>
                <p>Three things to read out of that table, and the third is the important one.</p>
                <p><strong>First, the positive value is identical in all three columns.</strong> <code>1000000</code> has the high bit of its final byte clear, so signed and unsigned decoding agree and so does the widening. <strong>A decoder with no signed LEB128 passes every positive value in the module.</strong> That is why the bug survives testing.</p>
                <p><strong>Second, the negative values are wrong by wildly different amounts in the unsigned column.</strong> &minus;1 becomes 127, a small error. &minus;1000000 becomes 1097152, an error of 2097152. The unsigned decoder is not off by a constant, so no single correction factor will rescue it, and the size of the error grows with the magnitude of the value.</p>
                <p><strong>Third, look at the last column and compare it with the disassembler's own output:</strong></p>
                <pre><code>$ wasm-objdump -d neg.wasm | grep const
   000049: 41 7f        | i32.const 4294967295
   00004f: 41 c0 84 3d  | i32.const 1000000
   000056: 41 c0 fb 42  | i32.const 4293967296
   00005d: 42 7f        | i64.const 18446744073709551615</code></pre>
                <p>Every one of those matches the "widened unsigned" column exactly, including the 64-bit case at 18446744073709551615. <strong>So <code>wasm-objdump</code> decodes <code>i32.const</code> and <code>i64.const</code> operands and prints them as unsigned.</strong></p>
                <p>That is not a bug in the disassembler, and the distinction matters. The encoding <em>is</em> signed LEB128 &mdash; the signed column above proves it, because it recovers the source constants exactly. What the disassembler does is take the decoded signed value and display it in the unsigned form of its own type, which is a presentation choice and arguably a defensible one: a 32-bit value printed unsigned is unambiguous, where &minus;1 could be mistaken for a label. But it means <strong>a reader who takes the disassembler's number as the constant will compute the wrong answer</strong>, and will compute it wrong for exactly the constants most likely to appear in real code: &minus;1, and small negative offsets.</p>
                <h3>Decoding a multi-byte value by hand</h3>
                <p>The negative one-million case, since it has all three features at once &mdash; several bytes, a final byte with bit 6 set, and a value that needs the sign step:</p>
                <div class="hex-dump">
                    <pre>bytes:  c0    fb    42
        |     |     |
        |     |     +-- 0x42, high bit clear: this is the LAST byte
        |     +-------- 0xfb, high bit set: continue
        +-------------- 0xc0, high bit set: continue

groups, least significant first:
    0xc0 and 0x7f = 0x40 = 64
    0xfb and 0x7f = 0x7b = 123
    0x42 and 0x7f = 0x42 = 66

value  = 64 + (123 &lt;&lt; 7) + (66 &lt;&lt; 14)
       = 64 + 15744 + 1081344
       = 1097152

now the sign: the LAST byte is 0x42, whose bit 6 (0x40) IS set,
so this is negative. Subtract one more group:
       1097152 - (1 &lt;&lt; 21)
       = 1097152 - 2097152
       = -1000000
</pre>
                </div>
                <p>The step that matters is the last one. Notice that <code>0x42</code> has its high bit clear &mdash; so it <em>is</em> the last byte &mdash; and its bit 6 is set, which is what says "negative". Those are two different bits of the same byte doing two different jobs, and confusing them is the classic LEB128 bug. The high bit answers "is there another byte"; bit 6 answers "is the value negative".</p>
                <p>Also worth noticing from the arithmetic: the intermediate value <strong>1097152</strong> is the same number the unsigned decoder produces. Signed and unsigned LEB128 assemble the <em>same bits</em>; the only difference is the final adjustment. So a decoder that gets the sign step wrong and a decoder that uses the wrong function produce identical bytes and identical intermediate values &mdash; which is why neither can be caught by comparing intermediate state.</p>
                <h3>Where each one is used, and why the split exists</h3>
                <p>The rule is not arbitrary, and it follows from what each number means:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">Encoding</th><th scope="col">Why</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>section size, name length, entry counts</td><td>unsigned</td><td>A count is never negative, and the unsigned encoding of a small positive is one byte</td></tr>
                        <tr><td>indices: type, function, local, label, global</td><td>unsigned</td><td>Same. An index into anything in a module is a position, and positions are non-negative</td></tr>
                        <tr><td>limits: memory and table minimum and maximum</td><td>unsigned</td><td>Page counts and element counts</td></tr>
                        <tr><td><code>i32.const</code>, <code>i64.const</code></td><td><strong>signed</strong></td><td>They are constants, and constants are negative roughly half the time</td></tr>
                        <tr><td><code>br_table</code> targets, and other relative offsets</td><td>unsigned</td><td>Relative in the instruction stream, so the sign is implicit in the arithmetic rather than stored</td></tr>
                    </tbody>
                </table>
                <p>The row that is easy to get wrong is the last one, and it is worth pausing on. A branch to an earlier label is a <em>negative</em> distance, and you would expect it to be signed. It is not: <code>br_table</code> depths are unsigned, because the label indices are unsigned and the target is looked up rather than computed. Meanwhile <code>i32.const</code> is signed, because it is a value. <strong>So "is this number a distance or a position" is the question, not "is it a distance".</strong> A reader that assumed signed-wherever-there-is-offset would be wrong here, and wrong in a way that produced an out-of-range index rather than a wrong constant.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Writing the decoder, because the two-function split is the design and the design is what prevents the bug. This is the version the course ships:</p>
                <div class="formula">
def read_uleb128(b, p):
    result = 0
    shift  = 0
    while True:
        byte = b[p]; p += 1
        result |= (byte and 0x7f) &lt;&lt; shift
        if not (byte and 0x80):        # high bit clear: last byte
            return result, p
        shift += 7

def read_sleb128(b, p):
    result = 0
    shift  = 0
    while True:
        byte = b[p]; p += 1
        result |= (byte and 0x7f) &lt;&lt; shift
        shift += 7
        if not (byte and 0x80):        # high bit clear: last byte
            if byte and 0x40:          # bit 6 set: negative
                result -= (1 &lt;&lt; shift)
            return result, p
</div>
                <p>Compare the two loops. They are nearly identical, and the difference is two lines: signed increments <code>shift</code> <em>before</em> testing the last byte, and applies the sign adjustment after. Unsigned does not need either, because a count has no sign and there is nothing to subtract.</p>
                <p>Now the guardrails, because a decoder without them will be handed something it should refuse:</p>
                <div class="formula">
three checks a LEB128 reader should make, and what each is for

1. LENGTH
   if more than 10 bytes: reject
   a 64-bit value needs at most ceil(64 / 7) = 10 bytes.
   Without the check, a run of 0x80 bytes makes shift grow without
   bound and a hostile file can ask for gigabytes of arithmetic.
   This is the check that matters most: it is the difference between
   a decoder and a denial-of-service.

2. OVERFLOW
   if shift is already 63 and the byte has bits above what is left:
       reject
   "i32.const" with a 10-byte operand that overflows 32 bits is
   malformed, and a reader that silently truncates produces a
   constant that is not the one in the file.

3. THE RIGHT FUNCTION
   know, per field, whether the field is signed
   this is the one that cannot be checked mechanically
</div>
                <p>The third check is the one that matters most in practice, and it is worth being honest about why: <strong>there is no way to detect it from the bytes.</strong> The other two are self-evident properties of the encoding &mdash; a value cannot need more than ten bytes, and a 32-bit field cannot hold a 40-bit number. But given <code>0x7f</code> with no field context, &minus;1 and 127 are equally consistent with the file. A reader cannot be self-checking here. It has to be <em>written</em> correctly, from a table saying which fields are signed, and reviewed by someone checking that table.</p>
                <p>That is a general property worth noticing about formats. Some of a format's rules are checkable at runtime and some are not. WebAssembly is unusually well designed in the checkable category &mdash; the validator verifies types, arities, indices, and memory bounds before a single instruction runs, which is why an untrusted module is safe to hand to a JIT. But the encoding layer sits <em>below</em> the validator, and a decoder has to be right before any validation can happen. <strong>The layer that decides what the bytes mean is the layer that cannot check itself, and that is true of every binary format ever designed.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ python3 courses/wasm/assets/samples/wasm_decode.py --hex neg.wasm
$ wasm-objdump -d neg.wasm | grep const</code></pre>
                <ul>
                    <li><strong>Verify the four-immediate table yourself.</strong> Read the operands out of <code>neg.wasm</code> with <code>wasm_decode.py</code>, then decode each one three ways by hand. The one that matters is <code>c0 fb 42</code>, because it has all three features &mdash; three bytes, a final byte with bit 6 set, and a value that needs the subtraction. Work it on paper before you look at the answer.</li>
                    <li><strong>Make the unsigned decoder fail visibly.</strong> Change <code>read_sleb128</code> in the shipped decoder to drop the sign adjustment, run it on <code>neg.wasm</code>, and confirm every negative constant becomes a large positive. Then change it to drop the <code>shift += 7</code> before the test, which breaks multi-byte values only, and see which of the four constants that catches. The two bugs have different footprints, and a reader who has met one does not automatically avoid the other.</li>
                    <li><strong>Find the one-byte boundary in a real file.</strong> 63 is <code>0x3f</code> and 64 is <code>0x40</code>, one byte each, with the second being negative. 64 needs no second byte and is positive. Write the boundary out: &minus;64, &minus;63, ..., &minus;1, 0, 1, ..., 63 &mdash; and check that the encoding is one byte for all of them. <strong>That is the property the sign bit buys, and seeing it is a hundred times clearer than being told it.</strong></li>
                    <li><strong>Confirm the two-byte size encoding on real data.</strong> The custom section appended to <code>long_custom.wasm</code> is 244 bytes and encodes as <code>f4 01</code>. Add a section over 16,384 bytes and confirm it widens to three bytes. Two bytes is a coincidence of small files; three proves the encoding is general rather than a special case.</li>
                    <li><strong>Test the length guard.</strong> Construct a section whose size field is ten <code>0x80</code> bytes. A decoder with the guard rejects it; one without allocates indefinitely. This is the most practically important line in the decoder, and it is the one that is easiest to leave out because no legitimate file triggers it.</li>
                    <li><strong>Account for every signed field.</strong> Go through the instruction opcodes and list which have signed immediates. <code>i32.const</code> and <code>i64.const</code> are the obvious ones. Find the ones you did not expect &mdash; there is at least one in the SIMD instruction set &mdash; and check each against real bytes. <strong>This table is the part of a decoder that cannot be verified by testing, so it deserves the most attention.</strong></li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a <code>i32.const</code> instruction is followed by the bytes <code>c0 fb 42</code>. Read the constant three ways, and say which one the program means.</p>
                <div class="quiz" id="quiz-wasm-leb128-1">
                    <button class="quiz-option" data-correct="true" data-explain="The program means negative one million, and working it through is the whole point of the question. The bytes assemble least-significant-group-first: 0xc0 masked to seven bits is 64, 0xfb masked is 123, 0x42 is 66, giving 64 + 15744 + 1081344 = 1097152. The final byte is 0x42, whose high bit is clear, so it is the last byte, and whose bit 6 is set, so the value is negative. One more group is subtracted, 2 to the power of 21, and 1097152 - 2097152 = -1000000. The unsigned reading of 1097152 is the intermediate value both encodings share, which is why it appears in the table and why a reader cannot catch the error by comparing intermediate state. The widened unsigned figure of 4293967296 is what the disassembler displays, and it is -1000000 plus 2 to the 32nd, the same bits presented without a sign." onclick="checkQuiz('quiz-wasm-leb128-1', this)"><strong>&minus;1000000</strong>. The groups assemble to 1097152, the final byte <code>0x42</code> has bit 6 set, so subtract 2<sup>21</sup> to get &minus;1000000. The unsigned reading gives 1097152, and the unsigned 32-bit reading gives 4293967296</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the intermediate value every signed LEB128 decoder passes through, and the unsigned answer. It is wrong because the final byte 0x42 has bit 6 set, which is the signal that the value is negative, and the decoder is required to subtract one more group on that basis. A decoder that stops before the sign step is a decoder with the sign rule missing, and it produces this number." onclick="checkQuiz('quiz-wasm-leb128-1', this)"><strong>1097152</strong>, because the three groups are 64, 123 and 66 and that is what they add up to</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is what the disassembler prints, and it is the same 32 bits as negative one million with the sign stripped, so the two answers describe the same field. The question is which one the program means, and the answer is determined by the field's declared signedness rather than by presentation. i32.const takes a signed operand, so the constant is negative one million; a reader that takes the displayed number as the constant will compute a different result, which is a real hazard and the reason this concept exists." onclick="checkQuiz('quiz-wasm-leb128-1', this)"><strong>4293967296</strong>, which is the value <code>wasm-objdump</code> prints for these bytes</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing an interpreter for WebAssembly. Arithmetic works. Comparisons work. Loops work. But one function is subtly wrong: it returns a plausible result, and that result is wrong only for some inputs, and always wrong in the same direction. <code>i32.const</code>, <code>i32.add</code> and <code>local.get</code> are all implemented and all tested against a reference interpreter on a large generated test suite. What is the most likely defect, and why did the test suite not find it?</p>
                <div class="quiz" id="quiz-wasm-leb128-2">
                    <button class="quiz-option" data-correct="true" data-explain="The symptom narrows it to the constant decoder. Wrong only for some inputs, always in the same direction, with arithmetic and control flow demonstrably correct, is the signature of a value being decoded correctly in magnitude and wrongly in sign: the same bits, presented as positive. And a generated test suite built by the same understanding of the format is the reason it survived. If the generator emits positive constants, the reference agrees with the implementation on every case and the test is a tautology. The diagnostic that breaks the deadlock is to construct a constant the generator will not produce, decode the bytes by hand, and compare, and the way to stop the class of bug is to make the two decoders structurally distinct as the shipped decoder is, with separate unsigned and signed functions, so that the wrong one cannot be reached by forgetting a flag. The general habit is that a differential test against your own model proves the implementation matches your understanding, and that is not the same as proving either is right." onclick="checkQuiz('quiz-wasm-leb128-2', this)">The signed LEB128 decoder for <code>i32.const</code> operands is missing its sign step, so negative constants come out as large positives. The test suite did not find it because a generated suite tends to use small positive constants, and every positive constant decodes identically under both rules</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a good instinct about a real class of bug, and the reported symptom argues against it here. Arithmetic being correct while one function is wrong points at how values enter that function, not at the operation it performs, since add and the comparisons are already right. And 'always in the same direction' does not fit an overflow, which produces a value that wraps in whichever direction the arithmetic takes it, with no consistent sign." onclick="checkQuiz('quiz-wasm-leb128-2', this)">Your arithmetic is overflowing 32 bits somewhere, and the test inputs did not happen to reach the overflow case</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a differential test against your own model proves the implementation matches your understanding. To break a tie you need a case your model will not generate &mdash; and for a signedness bug, that means a negative number on purpose.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>LEB128 is not WebAssembly's invention and it is not its only one. The same encoding appears in three formats in this collection, and each use teaches something slightly different about why it exists.</p>
                <p>In <a href="/courses/dwarf/lessons/dwarf-loclists">DWARF</a> the encoding is where a silent bug is easiest to make, because there the field's signedness is decided by the <em>abbreviation table</em> rather than by the format. A reader must consult a table to learn whether a given operand is signed, and getting that wrong is the bug the location-expressions concept warns about with <code>0x5c</code> being &minus;36 and not 92. In <a href="/courses/coff/lessons/coff-archives">COFF's archive format</a> the size field is <strong>decimal</strong> text rather than binary, which is a remarkable choice for a format that is otherwise entirely binary &mdash; and it is a reminder that a format can mix encodings when humans need to read the file. In <a href="/courses/elf/lessons/relocation-entries">ELF</a> the LEB128 fields are comparatively rare, because ELF predates the technique.</p>
                <p>WebAssembly adopted it wholesale, and the reason is visible in the numbers this concept opened with: <strong>a WebAssembly module is dominated by small integers</strong> &mdash; indices, counts, offsets, constants &mdash; so the one-byte case is the common case, and a variable-width encoding is close to free. A format with a dozen large fields, like ELF, gains little by switching and loses the ability to seek to a field by arithmetic on its offset.</p>
                <p>One consequence of the encoding belongs to the container rather than to the numbers, and it is worth carrying forward. Because a LEB128 is self-delimiting, <strong>a section's content cannot be indexed without decoding it</strong> &mdash; there is no stride, so you cannot compute the offset of the third entry without walking past the first two. That is why the Code section has to be read in order to find the third function's body, and it is the reason the next module's first concepts are about how bodies are found rather than about what is in them.</p>
                <p>That closes Module 1. The container is decoded end to end: eight fixed bytes, a framing of identifier and length, fourteen section kinds in a required order, and one variable-width encoding governing every number in between. What remains in the format is what those numbers <em>mean</em> &mdash; the declaration sections, the code section, and the two sections that place data &mdash; and those are the subject of the modules that follow.</p>
                <p>Back to the <a href="/courses/wasm">course index</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-sections">Previous: Sections</a></span>
                <span><a href="/courses/wasm/lessons/wasm-types">Next: The Type Section</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
