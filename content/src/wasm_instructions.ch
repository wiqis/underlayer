// WebAssembly Course — Module 3: The Body
// Concept: instruction encoding — the one-byte opcode space, why the top four
// bits are reserved, and the immediates that hide in plain sight.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_instructions() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Instruction Encoding — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>Instruction Encoding</h1>
            <div class="lesson-meta">24 min &middot; Module 3: The Body &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every other section stores data. The code section stores a program, and a program's opcodes are the one part of a binary format that a reader has to understand <em>completely</em> to do anything at all. A reader that cannot decode an instruction stream cannot disassemble, cannot validate, cannot compile, and cannot find a function &mdash; there is no partial credit.</p>
                <p>That constraint produced a decision that is visible in every single byte: <strong>the opcode space is one byte, and the top four bits of that byte are reserved for a prefix.</strong> Only 0x00 to 0x0f are opcodes directly, and anything from 0x10 to 0xff is either a prefix or an instruction in one of sixteen prefixed subspaces.</p>
                <p>The reason is extension, and the reason it is worth thinking hard about is that it shows a genuine tension in format design. A dense one-byte space &mdash; 256 opcodes, no prefix, immediate-free &mdash; would be the most compact possible encoding and would fit a JavaScript JIT's dispatch perfectly. Taking a quarter of it away to guarantee room for future proposals spends a real, permanent cost on a speculative benefit. <strong>That trade was the right one, and the history of the format's growth is the evidence</strong> &mdash; but it is a trade, not a free win, and the reason it was accepted is worth being able to state.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>An instruction is an opcode byte, then zero or more <em>immediates</em>. The immediates are the operands the encoding needs beyond the stack, and there are five kinds in the core format:</p>
                <div class="formula">
instruction:
    opcode                      one byte, possibly after a prefix

    then, depending on the opcode, zero or more of:
    u32                         an index: local, function, global, label, type
    s32/s64                     a constant, as a SIGNED LEB128
    4 or 8 raw bytes            a float, little-endian
    blocktype                   one byte: 0x40 for empty, or a valtype,
                                or a signed LEB type index
    memarg                      TWO fields: alignment, then offset
</div>
                <p><strong>Only the opcode byte tells you which immediates follow.</strong> There is no length prefix on an instruction, no way to skip one without knowing what it is, and no way to walk the stream without a table. A disassembler is fundamentally a large dispatch on one byte, and the shape of that dispatch is the shape of the opcode space.</p>
                <h3>The prefix scheme</h3>
                <p>Here is the layout, and it is a genuinely clever piece of packing:</p>
                <div class="hex-dump">
                    <pre>  0 1 2 3 4 5 6 7   0 1 2 3 4 5 6 7
  +---------------+   +---------------+
  | 0 0 0 0 x x x |   | p p p p x x x |
  +---------------+   +---------------+
     direct opcode      p = the prefix number, x = the low 3 bits

  0x00 - 0x0f : opcodes directly (unreachable, nop, block, loop, if, ...)
  0x10        : call
  0x20        : local.get / local.set / local.tee / global.get / global.set
  0x28 - 0x3e : loads and stores (each has an alignment + offset)
  0x3f        : memory.size
  0x40        : memory.grow
  0x41-0x44   : the four const opcodes
  0x45-0xc4   : comparison, arithmetic, conversion -- the bulk
  0xd0 - 0xd2 : reference instructions
  0xfc        : a PREFIX -- the sub-opcode follows as a LEB128
  0xfd        : a PREFIX -- SIMD
  0xfe        : a PREFIX -- atomics
</pre>
                </div>
                <p>Read that carefully, because the low three bits are doing real work. <strong>Each prefixed subspace holds 128 instructions, numbered 0 to 127</strong>, and the prefix byte chooses the subspace. So <code>0xfc 0x00</code> is "prefix 0xfc, instruction 0" &mdash; a truncating float-to-int conversion, of which there are eight variants for signed and unsigned and 32-bit and 64-bit.</p>
                <p>And <strong>the prefixed sub-opcode is a LEB128, not a byte.</strong> That is the detail that surprises people, and it is not an accident: it means the sub-space is not limited to 128 entries in principle, only in practice so far. The SIMD prefix has needed a few more than a byte would cleanly give, and the LEB128 form is why it did not have to be renumbered. A reader that reads the sub-opcode as a single byte works today and breaks the day a proposal needs instruction 128 in some subspace &mdash; which is a smaller version of the same lesson the <a href="/courses/wasm/lessons/wasm-leb128">LEB128 concept</a> taught about section sizes.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>A real compiled body, dumped with the byte encodings, and every row is verified against wabt's own disassembly:</p>
                <div class="hex-dump">
                    <pre>  local.get 0        20 00          i32.add        6a
  local.get 1        20 01          i64.add        7c
  local.get 2        20 02          f32.add        92
  local.get 3        20 03          f64.add        a0
  drop               1a             i32.eq         46
  nop                01             else           05
  return             0f             end            0b

  i32.const 1        41 01          i64.const 1    42 01
  f32.const 1.0     43 00 00 80 3f
</pre>
                </div>
                <p>Two things to notice before going further. <strong>The numeric opcodes are not contiguous by operation</strong> &mdash; <code>i32.add</code> is <code>0x6a</code>, <code>i64.add</code> is <code>0x7c</code>, <code>f32.add</code> is <code>0x92</code>, <code>f64.add</code> is <code>0xa0</code>, a gap of 18 each time. The opcode space is ordered by <em>type family</em> and then by operation, and the gaps are where a proposal would insert. And <strong>the type is in the opcode, not the immediate</strong>: there is no "add" opcode and no type field, there are four <code>add</code> opcodes. That is what lets a JIT dispatch on the opcode alone and know the operand types without decoding a byte.</p>
                <h3>Control flow and the block type</h3>
                <p>The structured control instructions all take one <em>block type</em> immediate, and it is the most interesting immediate in the format:</p>
                <div class="hex-dump">
                    <pre>  04 40        if    blocktype = 0x40  (empty: no params, no results)
  02 40        block blocktype = 0x40
  03 40        loop  blocktype = 0x40
  0b           end
  05           else
</pre>
                </div>
                <p><code>0x40</code> is the empty block type, and it is the third encoding of "nothing" in the format alongside a zero result count and a zero-length name. A block type can be:</p>
                <div class="formula">
<pre>
  0x40                    the empty type: no parameters in, no results out
  0x7f 0x7e 0x7d 0x7c     a single result of that value type
  0x70 0x6f               (not legal as a block type, but adjacent in the
                          encoding space -- a block cannot produce a reference)
  a signed LEB128 >= 0    a TYPE INDEX: this block takes parameters and
                          produces results, using the type section

  and a NEGATIVE signed LEB128 is reserved for future extensions
</pre>
                </div>
                <p><strong>The block type is overloaded, and the disambiguation is the sign.</strong> A byte <code>0x7f</code> is a value type; a multi-byte LEB like <code>0x00</code> is type index 0. A reader that tries to read the block type as a LEB first will read <code>0x40</code> as the LEB value 64, which is a type index &mdash; and then go looking for type 64 in a module that has three. So the rule is: <strong>peek one byte; if it is a value type or <code>0x40</code>, that is the whole block type; if it is anything else, it is a signed LEB index.</strong> That is a one-byte lookahead and it is genuinely fiddly, and it is why a disassembler's block-type handling is a common source of bugs.</p>
                <div class="callout callout-warn">
                    <strong>The block type is the field in this course that is hardest to get right, and the reason is a design decision rather than an accident.</strong> Every other block type could have been encoded as a type index &mdash; the format could have declared an empty type in the type section and used it &mdash; and it does not, because that would put a type index in the hot path of every branch. The format traded a one-byte-lookahead ambiguity for smaller and faster code. <strong>This is a recurring pattern: an encoding that is technically redundant is often kept because removing the redundancy costs something in the decoder.</strong> The same reasoning kept the <code>0x00</code> elemkind byte in the element section's function forms, which a later concept covers, and kept the <code>0x40</code> empty block type even though it is not a value type.
                </div>
                <h3>Memory instructions: two immediates, and one is a logarithm</h3>
                <p>Loads and stores take a <code>memarg</code>, and it is two fields, not one:</p>
                <div class="hex-dump">
                    <pre>  28 02 00        i32.load      align = 2, offset = 0
  2c 00 04        i32.load8_s   align = 0, offset = 4
  28 02 00        the 0x28 is the opcode, then TWO LEB128s

  align is a LOGARITHM, not a byte count:
      align 0  ->  2^0 = 1 byte
      align 1  ->  2^1 = 2 bytes
      align 2  ->  2^2 = 4 bytes   &lt;- natural for an i32 load
      align 3  ->  2^3 = 8 bytes   &lt;- natural for an i64 load
</pre>
                </div>
                <p><strong>The alignment immediate is <code>log2</code> of the byte alignment.</strong> That is a compression, and it is a good one &mdash; the value is almost always 0, 1, 2 or 3, so a single byte carries four bits' worth of meaning. But it means a reader that treats it as a byte count will compute a bounds check that is 4&times; too strict for an <code>i32.load</code>, and reject a module that is perfectly legal. Or, if it divides, it will compute <code>offset / align</code> and get nonsense.</p>
                <p>And <strong>both immediates matter for correctness, and they are not the same kind of thing.</strong> The <code>offset</code> is a static constant baked into the instruction: it is an immediate, and because it is a LEB128 it can be enormous, up to 2<sup>32</sup>-1. The <code>align</code> is a <em>hint</em> to the engine, promising the access is aligned; a runtime may use it to emit an aligned instruction. <strong>An engine that trusts the hint without checking, on a module it did not produce, gets a fast unchecked load on an unaligned address</strong> &mdash; and on some architectures that is an instant fault. The validator does check that the declared alignment is not greater than the natural alignment of the access, which prevents a module from lying <em>upwards</em>; it deliberately does not check that the address <em>is</em> aligned, because that is a run-time property.</p>
                <h3>Two immediates where the original specification had one</h3>
                <p>The best example of the format growing is <code>call_indirect</code>:</p>
                <div class="hex-dump">
                    <pre>  11 00 00        call_indirect
                     |  +-- table index = 0
                     +----- type index = 0
</pre>
                </div>
                <p>Two LEB128s. The original specification had only the type index, and the reference-types proposal appended a table index so that a <code>call_indirect</code> could name which table's entry to read. <strong>A reader written against the original spec reads one LEB, gets the type index right, and treats the table index byte as the next opcode</strong> &mdash; which will usually be something plausible, and will desynchronise the rest of the function.</p>
                <p>Compare <code>call</code>, which has one:</p>
                <div class="hex-dump">
                    <pre>  10 00        call 0
</pre>
                </div>
                <p>and the two memory instructions, which also take a memory index even though a module may have only one:</p>
                <div class="hex-dump">
                    <pre>  3f 00        memory.size 0
  40 00        memory.grow 0
</pre>
                </div>
                <p>Those trailing <code>00</code> bytes are pure forward compatibility. The multiple-memory proposal makes the index meaningful; today it is always zero, and a reader that omits it will be wrong the day it is not. <strong>Paying one byte per instruction today to avoid a format change tomorrow is a trade the design made deliberately, and it is the same instinct as reserving the top four opcode bits.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Disassembling a stream, which is the only operation that makes the design choices above pay off or cost. The inner loop is a dispatch on one byte:</p>
                <div class="formula">
disassemble(code, pc) -> (text, next_pc):

    b = code[pc]

    if b >= 0xfc:
        prefix = b
        sub    = read_uleb128()          # a LEB, NOT a byte
        if prefix == 0xfc: return numeric_op(sub, immediates_by_kind[sub])
        if prefix == 0xfd: return simd_op(sub, immediates_by_kind[sub])
        if prefix == 0xfe: return atomic_op(sub, immediates_by_kind[sub])
        reject: unknown prefix

    opcode = b
    spec = OPCODES[opcode]               # the table. there is no alternative.
    if spec is absent: reject           # not "skip one byte and continue"

    read each immediate named by spec, in the order spec names them
    return (spec.name, those immediates, pc)
</div>
                <p>Three things in that are consequences of the design, not of the algorithm. <strong>The opcode table is unavoidable</strong> &mdash; there is no length prefix, so a reader cannot skip an instruction it does not recognise, and refusing is the only safe response. That is a real cost of the format and it is why adding an opcode is a specification change that old readers cannot tolerate, unlike a prefixed opcode which old readers at least reject cleanly.</p>
                <p><strong>Immediate widths are a property of the opcode</strong>, so the table has to carry the arity and kind of every immediate. A disassembler that guesses "an opcode ending in a subscript digit probably has an index" will be wrong: <code>memory.size</code> and <code>memory.grow</code> take an index, and so do the control instructions, but <code>i32.const</code> takes a signed constant, and the two are encoded identically as a LEB128. <strong>The difference between an index and a constant is not in the encoding at all</strong> &mdash; it is semantic, and a reader cannot tell them apart from the bytes.</p>
                <p>And <strong>the boundary check is the whole safety property.</strong> Every instruction that reads memory has a memory index, and every index has to be checked against the declared memory count before the access. <code>28 02 00</code> at the end of a stream with no memory is a trap, not a segfault &mdash; the module is rejected at validation, before a single instruction executes. Compare a native <a href="/courses/coff/lessons/coff-relocations">COFF relocation</a> or a <a href="/courses/elf/lessons/relocation-entries">ELF relocation</a>, where an out-of-range index is a link-time or load-time failure that a debugger may step straight past. <strong>WebAssembly moves that class of error from "the loader's problem" to "the validator's problem", and the reason it can is that the instruction encoding is fully self-describing.</strong></p>
                <p>One practical consequence worth knowing before you write a disassembler. The <code>align</code> immediate is a hint, and a compiler is free to emit a <em>smaller</em> alignment than the access actually needs &mdash; <code>i32.load</code> with <code>align = 0</code> is perfectly legal, meaning "no alignment guaranteed". A disassembler that prints the effective alignment as <code>2^align</code> is being precise; one that prints <code>align</code> raw is being terse. wabt prints the raw value, so <code>i32.load 2 0</code> means align 2, offset 0 &mdash; <strong>and the first number is not a byte count, however much it looks like one.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -d ops.wasm
$ wasm-objdump -d body.wasm</code></pre>
                <ul>
                    <li><strong>Build the opcode table from the disassembly, not from memory.</strong> Take a real module, dump every instruction, and tabulate opcode to name. Then check your table against <code>wasm-objdump</code> on a module using instructions your table does not have. <strong>The first missing one is instructive, because it is the moment a table stops being a complete answer</strong> &mdash; and the place to look for whether the prefix scheme made the extension clean or messy.</li>
                    <li><strong>See the alignment logarithm catch someone.</strong> Write a validator that treats <code>align</code> as a byte count instead of a log, and run it on <code>ops.wasm</code>. <code>i32.load</code> declares align 2, which your reader believes means 2 bytes, so it rejects a valid module. <strong>Producing a false rejection on purpose teaches you to read a validator's complaint carefully rather than assuming it is right.</strong></li>
                    <li><strong>Find the type-index block type.</strong> Write <code>(block (result i32) (i32.const 1))</code> and <code>(block (type $t))</code> where <code>$t</code> is <code>(func (param i32) (result i32))</code>. Read both block types back. The first is a single byte <code>0x7f</code>; the second is a multi-byte LEB index. <strong>Same instruction, two different immediate widths, and the disambiguation is a one-byte peek</strong> &mdash; now find out what happens if you get the peek wrong.</li>
                    <li><strong>Prove the trailing memory index is real.</strong> Read <code>memory.size 0</code> and <code>call_indirect</code> byte by byte and account for every byte. Then confirm that the memory index is always zero in today's format, and note what a reader that omits it would do. <strong>Forward compatibility has a price, and this is the smallest possible example of paying it.</strong></li>
                    <li><strong>Look at a real compiler's opcode usage.</strong> Compile a C file at <code>-O0</code> and at <code>-O2</code>, and compare the instruction histograms. <code>-O0</code> is dominated by <code>local.get</code>/<code>local.set</code>; <code>-O2</code> by <code>global.get</code> and memory loads. <strong>That difference is the compiled-code analogue of the <a href="/courses/wasm/lessons/wasm-code">local declaration grouping</a> finding</strong> &mdash; both are pictures of what an optimiser removes.</li>
                    <li><strong>Write a disassembler that refuses unknown opcodes, and feed it junk.</strong> Take a valid function body, flip one opcode byte to something unassigned, and confirm your disassembler stops with an error rather than printing nonsense and continuing. <strong>A disassembler that continues past an unknown opcode is a disassembler that will eventually claim a valid module is invalid, and the reason it does so is a one-byte change you can find in a diff.</strong></li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: three instruction encodings are <code>28 02 00</code>, <code>11 00 00</code> and <code>04 40</code>. Decode each one fully, and say what a reader written against the original 2017 specification would get wrong about the first two.</p>
                <div class="quiz" id="quiz-wasm-instructions-1">
                    <button class="quiz-option" data-correct="true" data-explain="Each is three different immediate shape. 0x28 is the i32.load opcode, followed by a memarg of two LEB128s: align 2, which is a logarithm and therefore 2^2 = 4 bytes, the natural alignment of an i32, and offset 0. 0x11 is call_indirect, followed by a type index of 0 and a table index of 0 -- two immediates where the original specification had one. 0x04 is the if opcode, followed by a block type of 0x40, the empty type. Against the 2017 specification, a reader of the first would treat align 2 as a two-byte alignment and reject a valid module, or divide rather than exponentiate; a reader of the second would read one LEB for the type index and then treat the table index byte as the next opcode, desynchronising the rest of the function. The block type is the one both would get right, though for the wrong reason if they read it as a LEB: 0x40 as an unsigned LEB is 64, a type index, which would send them looking for a type 64 that a three-type module does not have." onclick="checkQuiz('quiz-wasm-instructions-1', this)"><code>28</code> is <code>i32.load</code> with align 2 (meaning 4 bytes) and offset 0; <code>11</code> is <code>call_indirect</code> with type index 0 and table index 0; <code>04</code> is <code>if</code> with the empty block type. The 2017 reader would treat the alignment as a byte count, and would read only one immediate for <code>call_indirect</code> and desynchronise</button>
                    <button class="quiz-option" data-correct="false" data-explain="Two of the three are decoded wrong. For the load, 0x28 0x02 0x00 is not a memory index and not an offset field; the first immediate is the alignment, and it is a base-2 logarithm, so 2 means four bytes rather than two. And call_indirect takes two immediates, not one: the type index and then a table index, both zero here. The block type is right, which is the shape this error usually takes -- the one immediate that is a plain byte is read correctly and the two that need a rule are read wrongly. The rule being missed in both cases is that immediate kinds are not self-describing and have to come from the opcode's specification." onclick="checkQuiz('quiz-wasm-instructions-1', this)"><code>28</code> is <code>i32.load</code> with a memory index of 2 and an offset of 0; <code>11</code> is <code>call_indirect</code> with a single table index of 0; <code>04</code> is <code>if</code> with the empty block type. A 2017 reader would mis-handle the immediate widths but not the structure</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your disassembler works on every module produced by your toolchain. On a module from a newer toolchain, it prints a plausible instruction stream for the first function, then drifts: line numbers stop matching, the function ends at the wrong place, and the next function's output is nonsense. The module validates with <code>wasm-validate</code>. The first function that misbehaves contains exactly one <code>call_indirect</code>. What is the defect, and why did the output stay plausible for a while instead of failing immediately?</p>
                <div class="quiz" id="quiz-wasm-instructions-2">
                    <button class="quiz-option" data-correct="true" data-explain="The single call_indirect is the clue and it points at immediate count, not at an unknown opcode. If the newer toolchain had emitted an opcode your table does not know, your disassembler would have hit its refuse-unknown path and stopped with a clean error, and the first function would be where it stopped. Instead it printed plausible output and drifted, which is the signature of a width error: the reader consumed the wrong number of bytes and everything after is offset. call_indirect gained a table index after the reference-types proposal, so a reader that reads one LEB where the encoding has two takes the table index byte as the next opcode. The reason it stays plausible is that the byte that becomes an opcode is a small integer, and small integers in the 0x00-0x0f range are all real opcodes -- unreachable, nop, block, loop, if, and so on. A stray nop or block is easy to overlook in a listing, and a block consumes the following bytes as a block type, which absorbs instructions without complaint. That is why the failure looks like drift rather than garbage: the desync is being reinterpreted as valid instructions, and the accumulation of small misalignments only becomes visible when a structural marker like a function end is consumed as an operand. The general habit is to fail loudly on any misalignment. A disassembler that can detect that its position did not land on a plausible boundary should say so, because a silent desync is strictly worse than an error -- the error costs you one function, the silence costs you every conclusion you drew after it." onclick="checkQuiz('quiz-wasm-instructions-2', this)">Your reader reads one immediate for <code>call_indirect</code> where the encoding has two, so the table-index byte is decoded as an opcode and the stream drifts. It stays plausible because that byte is a small integer, and small integers are all real opcodes, so the misread bytes are absorbed as harmless instructions</button>
                    <button class="quiz-option" data-correct="false" data-explain="The evidence rules this out. A reader with the wrong immediate count desynchronises and stays in the 0x00-0xff opcode space forever, because it is reading real bytes and interpreting them with a real table. A reader with an out-of-range index reads a perfectly good LEB and produces a value that is merely wrong, and the module is valid, so every index in it is in range. That kind of bug produces a disassembler that mislabels a function or a local but keeps its structure intact -- which is not what drift looks like. The single call_indirect, mentioned specifically and singled out, is the format's one instruction known to have grown an immediate, which is what a well-posed question does for you." onclick="checkQuiz('quiz-wasm-instructions-2', this)">Your reader mis-handles the alignment immediate as a byte count, so the newer module's wider load offsets are being computed wrongly and the printed addresses drift</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a format with no instruction length prefix makes a width error silent, because the misread bytes usually land in a valid opcode space. Detect misalignment rather than trusting continuity, and prefer an error over a plausible wrong listing.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The one-byte-opcode-plus-prefix design has an exact precedent in x86, and the comparison is the point. <strong>x86 reserves its top nibble for sixteen prefix bytes and uses the low three bits for the base opcode</strong> &mdash; the same 4/3 split &mdash; and x86 has spent forty years regretting it, because the prefixes are consumed in an order nobody can remember and every one of them costs a byte. WebAssembly's prefixes are ordered and uniform, which is the design lesson, and the two share the cost. This course has no x86 lesson to point at, which is itself worth noting: the format deliberately kept only the idea and none of the baggage.</p>
                <p>The alternative designs make the trade concrete, and none of them is free. A <strong>fixed 4-byte instruction word</strong> &mdash; real RISC, and the PowerPC and SPARC encoding &mdash; has zero decoding cost, at the price of enormous code density loss, which is why a 32-bit ARM program is several times larger than the equivalent x86 one. A byte plus a length prefix, which is what several CISC formats do, is self-delimiting and costs an extra byte on every instruction, which is cheap when instructions average five bytes and expensive when they average one. WebAssembly took a third option that gets neither benefit fully: <strong>one byte of opcode, variable immediates, no length</strong>, which is the most compact of the three and the least robust, since a reader that loses sync has nothing to check against &mdash; and, as the <a href="/courses/wasm/lessons/wasm-objects">final concept</a> shows, a desync in a length-prefixed structure is the failure this format is most exposed to.</p>
                <p>The <code>memarg</code>'s two-field structure connects to <a href="/courses/elf/lessons/section-header-table">the ELF <code>p_align</code> and <code>p_offset</code></a> and to <a href="/courses/pe/lessons/pe-section-table">the PE section alignment</a>. In all three the alignment is a power of two and a loader has to round a file offset up to it, and the same arithmetic appears here as an exponent the decoder must evaluate. The difference is that WebAssembly stores the logarithm, which is one fewer byte and one more place to get it wrong &mdash; and the <a href="/courses/coff/lessons/coff-characteristics">COFF characteristics word</a> collects several such one-bit facts into a single 16-bit value, which is the same compression applied to a whole set of flags.</p>
                <p>And the block type connects to <a href="/courses/coff/lessons/coff-symbol-table">COFF's auxiliary records</a> and to <a href="/courses/dwarf/lessons/dwarf-dies">DWARF's <code>DW_TAG_</code> prefix</a>, because all three are a one-byte-or-tag selector choosing among record shapes, and all three are overloading a small integer space. The WebAssembly case is the most interesting of the three because the selector is <em>overloaded on a value that is itself meaningful</em> &mdash; <code>0x7f</code> is a value type in a block type context and a valtype everywhere &mdash; so the disambiguation is a lookahead rather than a table.</p>
                <p>The format's remaining sections put these instructions to work. <a href="/courses/wasm/lessons/wasm-elements">The element section</a> fills the tables these instructions index, and <a href="/courses/wasm/lessons/wasm-data">the data section</a> fills the memories these instructions address &mdash; and both have grown the same way <code>call_indirect</code> did, one proposal at a time, which is why the element section has eight encodings and the data section three.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-code">Previous: The Code Section</a></span>
                <span><a href="/courses/wasm/lessons/wasm-elements">Next: Element and Data Segments</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
