// WebAssembly Course — Module 3: The Body
// Concept: the code section — body framing, the run-length local declarations,
// and why the group count is not the number of locals you wrote.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_code() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Code Section — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>The Code Section</h1>
            <div class="lesson-meta">22 min &middot; Module 3: The Body &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Two sections earlier the format declared functions without giving them bodies: the <a href="/courses/wasm/lessons/wasm-types">type section</a> says a signature and the <a href="/courses/wasm/lessons/wasm-types">function section</a> says which signature each function has. Neither says what the function does. That is the code section's whole job, and it is the first part of the format you have reached that contains instructions rather than declarations.</p>
                <p>The split exists for a reason worth knowing. A module's declarations are a small, highly-compressible set of facts that a validator wants to check exhaustively &mdash; every type, every index, every limit &mdash; before it trusts anything. Its code is a large stream of bytes that the same validator has to walk in full anyway. Separating them means a reader can load and check the declarations once, and then stream the code.</p>
                <p>What makes the code section interesting is its local declaration encoding, which is the one place in the format where a compression trick changes the shape of the data in a way that is easy to misread. A function with seven locals does not have seven local entries. It has a <em>group count</em>, and the groups are run-length encoded &mdash; and the compiler merges adjacent locals of the same type, so the number of groups is not the number of declarations in your source either.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two levels of framing. The section declares how many bodies; each body declares its own size:</p>
                <div class="formula">
code section:
    count                       how many function bodies follow

body, repeated `count` times:
    size                        this body's size in bytes
    locals                      the run-length local declaration table
    instructions                the instruction stream
</div>
                <p>Three fields per body, and the middle one is where the lesson is. The <code>size</code> field is what makes the code section seekable in the same way the section framing is: a reader can find the fifth function's body without decoding the first four, because each body says how long it is.</p>
                <h3>The local declaration table</h3>
                <p>This is the part that surprises people. Locals are not listed one at a time. They are listed in <em>groups</em>, and each group is a count followed by a type:</p>
                <div class="formula">
locals:
    group_count                 how many groups follow

group, repeated `group_count` times:
    count                       how many locals of the next type
    valtype                     the type they all are
</div>
                <p>So a function with ten <code>i32</code> locals costs three bytes, not eleven. And here is the part that catches people out, verified from a real module: <strong>adjacent groups of the same type are merged</strong>. Write</p>
                <pre><code>(local i32) (local i32)</code></pre>
                <p>and the compiler emits <em>one</em> group of <code>2 &times; i32</code>, not two groups of <code>1 &times; i32</code>. A reader that assumes one group per source declaration will count twice as many groups as there are, and then read the second one out of the middle of the instruction stream.</p>
                <div class="callout callout-warn">
                    <strong>Why the groups are ordered, and why that matters.</strong> The encoding is run-length over a <em>consecutive</em> run, not a histogram. <code>(local i32) (local f32) (local i32)</code> is <strong>three</strong> groups &mdash; <code>1&times;i32</code>, <code>1&times;f32</code>, <code>1&times;i32</code> &mdash; because the two <code>i32</code> declarations are not adjacent. And the order of the groups is the order the locals are numbered: <strong>local 0 is the first local of the first group</strong>, then local 1 is the second local of that group if the group has two, and so on. So <code>local.get 1</code> in a function whose first group is <code>3 &times; i32</code> means the second of those three, and a reader that numbers groups rather than locals will be off by a varying amount that depends on the group sizes before it.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>A function with locals of four different types, written to make the grouping visible:</p>
                <pre><code>(func $locals (param i32) (result i32)
  (local i32) (local i32) (local i64) (local f32) (local i32 i32 i32)
  (local.get 1))</code></pre>
                <p>Six local declarations in the source, of four distinct types, in three runs. Read the body out of the module:</p>
                <div class="hex-dump">
                    <pre>body size = 12
  0c                       0 locals groups? no --
  04                       FOUR groups
  02 7f                    group 0: 2 locals of 0x7f (i32)
  01 7e                    group 1: 1 local  of 0x7e (i64)
  01 7d                    group 2: 1 local  of 0x7d (f32)
  03 7f                    group 3: 3 locals of 0x7f (i32)
  20 01                    local.get 1
  0b                       end
</pre>
                </div>
                <p>Now compare the source with the encoding, and every design decision is visible:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Source</th><th scope="col">Encoded as</th><th scope="col">Why</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>(local i32)</code> <code>(local i32)</code></td><td>one group <code>2 &times; i32</code></td><td>adjacent and identical, so run-length encoded into one</td></tr>
                        <tr><td><code>(local i64)</code></td><td>one group <code>1 &times; i64</code></td><td>different type, so the run breaks</td></tr>
                        <tr><td><code>(local f32)</code></td><td>one group <code>1 &times; f32</code></td><td>different type, so the run breaks</td></tr>
                        <tr><td><code>(local i32 i32 i32)</code></td><td>one group <code>3 &times; i32</code></td><td>three in a row, one group</td></tr>
                    </tbody>
                </table>
                <p><strong>Four groups, not six declarations</strong>, and the two <code>i32</code> locals at the front have been absorbed into the first group. Seven locals total &mdash; two, one, one, three &mdash; across four groups, in eleven bytes of table.</p>
                <p>And the crucial detail: <strong>the groups were not reordered to make a better encoding.</strong> The first group is <code>2 &times; i32</code> even though there is also a <code>3 &times; i32</code> group later, and the compiler could have emitted <code>5 &times; i32</code> if the <code>i64</code> and <code>f32</code> were not in between. It did not, because <strong>the group order is the local numbering</strong>. Local numbering is part of the function's interface &mdash; every <code>local.get</code> and every <code>local.set</code> in the body refers to it &mdash; so the encoding is obliged to preserve the order rather than optimise it.</p>
                <p>That is worth pausing on, because it is the difference between an encoding that is merely compact and one that is also correct. A toolchain that sorted the groups by type would save a byte here and there and produce a module where <code>local.get 1</code> means something different. <strong>The compression is applied within a run, never across one.</strong></p>
                <h3>What the instruction stream looks like</h3>
                <p>Two more functions from the same module, one with no locals and one with a mismatched pair, to show the frame:</p>
                <div class="hex-dump">
                    <pre>$nolocals   body size = 4
  00                    0 local groups
  41 07 0b              i32.const 7 ; end

$multigrp   body size = 9
  02                    2 local groups
  01 7f                 1 x i32
  01 7c                 1 x f64
  41 01 1a 0b           i32.const 1 ; drop ; end

$t0        body size = 2
  00                    0 local groups
  0b                    end
</pre>
                </div>
                <p>Three things to read off that. The <strong>group count is present even when it is zero</strong> &mdash; a function with no locals still spends a byte saying so, and a reader that skips it will read <code>0x41</code> as the group count. The <strong>body size counts the local table</strong>, not just the instructions, so a reader that treats it as an instruction-stream length will stop in the middle of the declarations. And <code>end</code> is <code>0x0b</code> in every case &mdash; it terminates both a body and a constant expression, which is why the same walker decodes both.</p>
                <p>Note also what the body size is <em>not</em>: it is not the number of instructions, and it does not include the size field itself. <code>$locals</code>'s body is 12 bytes: 1 for the group count, 8 for four groups, and 3 for <code>local.get 1</code> and <code>end</code>. The <code>size</code> byte that said <code>12</code> is not one of those twelve.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Resolving a local index, which is the operation the encoding exists to make cheap, and the arithmetic that goes wrong if you number groups instead of locals:</p>
                <div class="formula">
given a local index N, walk the groups accumulating:

    index_of_this_group = 0
    for each group (count, valtype):
        if N &lt; index_of_this_group + count:
            this is the group
            the local is local number (count - (index_of_this_group + count - N))
                      = N - index_of_this_group   slots into the group
            its type is valtype
            stop
        index_of_this_group += count
</div>
                <p>Run it on <code>$locals</code>, whose groups are <code>2&times;i32, 1&times;i64, 1&times;f32, 3&times;i32</code>:</p>
                <div class="formula">
N=0   group 0 (2 x i32),  first i32     &lt;- a declared local
N=1   group 0 (2 x i32),  second i32    &lt;- local.get 1 in the source
N=2   group 1 (1 x i64),  the i64
N=3   group 2 (1 x f32),  the f32
N=4   group 3 (3 x i32),  first of the trailing three
N=5   group 3, second
N=6   group 3, third
</div>
                <p>So the local numbering is a flattening of the group list, and <code>N</code> indexes that flattening rather than the groups. Now the failure mode, and it is a good one because it is <em>mostly</em> right:</p>
                <ul>
                    <li>A reader that treats each group as one local would number the seven locals as 0&ndash;3, so <code>local.get 0</code> and <code>local.get 1</code> would be right and <strong>everything from <code>local.get 2</code> onwards would be wrong</strong>.</li>
                    <li>And "wrong" here means it reads a type out of the instruction stream, because the group table ends and the opcodes begin. The resulting function has the right arity, the right body size, and locals of nonsense types &mdash; and it will be caught by a validator, but only if the validator is checking types, which for a local access it must be.</li>
</ul>
                <p>That last point is the interesting one. <strong>A number of local types being wrong is not something a size check can see</strong>, and it is not something a section walk can see. It surfaces only when a type-aware consumer &mdash; a validator, or a JIT that specialises on types &mdash; reads the body and finds an <code>i32</code> operation on a local declared <code>f64</code>. Which is another way of saying that the run-length encoding is not merely a space optimisation: it makes the local <em>type</em> table a compressed representation, and every consumer has to decompress it before it can type anything.</p>
                <p>There is one more consequence of the encoding being per-body rather than per-module, and it is a design choice rather than a limitation. Two functions in the same module that both declare <code>(local i32) (local i32)</code> each carry their own <code>2 &times; i32</code> group. There is no shared local table, because there could not be: locals belong to a function's frame, and a frame exists only when that function is called. <strong>Local declarations are the one piece of per-function metadata that cannot be factored out of the function, and the format treats them that way.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -x body.wasm | sed -n '/^Code/,$p'
$ python3 courses/wasm/assets/samples/wasm_decode.py --hex body.wasm</code></pre>
                <ul>
                    <li><strong>Force every group count.</strong> Write a function with twenty locals of the same type, and one with twenty alternating between two types. The first is one group and three bytes of table; the second is twenty groups and eighty. <strong>The difference between a group count and a declaration count is the whole point of this concept, and twenty of each makes it unmissable.</strong></li>
                    <li><strong>Prove the merging is order-preserving, not sorted.</strong> Write <code>(local i32) (local f32) (local i32)</code> and confirm it produces three groups, not two. Then write <code>(local i32) (local i32) (local f32)</code> and confirm two. The encoding is an RLE over a sequence, and that is the whole rule.</li>
                    <li><strong>Count a real function's locals from the machine code.</strong> Take a compiled <code>-O2</code> function and read its body. You will usually find <strong>zero</strong> locals, because the optimiser promotes everything and the WebAssembly calling convention passes scalars in arguments rather than the stack. Contrast with <code>-O0</code>, where every C local becomes a WebAssembly local. <strong>That difference is the clearest possible picture of what an optimiser does to a function's frame.</strong></li>
                    <li><strong>Verify the body size arithmetic.</strong> For every function in a module, add up the group-count byte, the group table, and the instruction bytes, and check the total is the declared size. Do it for three functions with different shapes. A decoder that gets this wrong will not fail on the first function and will fail on the second, which is the worst possible behaviour.</li>
                    <li><strong>Build a deliberately mis-numbered reader and watch it break.</strong> Change the local resolver to treat each group as one local, run it on a function with more than one group, and confirm it reads a valtype byte out of the instruction stream. Then feed the result to <code>wasm-validate</code> and see what it says. <strong>The validator is the other reader of this course, and this is the one place it catches something the section walk cannot.</strong></li>
                    <li><strong>Look for a function whose locals exceed the argument count.</strong> A function's first locals are its parameters, so <code>local.get 0</code> on a function with one parameter is the parameter and <code>local.get 1</code> is the first declared local. Confirm that in the source and in the encoding together &mdash; it is the join between the <a href="/courses/wasm/lessons/wasm-types">type section</a> and this one, and getting it wrong means a debugger labels an argument as a local.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a function's local table is <code>04  02 7f  01 7e  01 7d  03 7f</code>. How many groups, how many locals, what are their types in order, and what would a reader that assumed one group per source declaration conclude?</p>
                <div class="quiz" id="quiz-wasm-code-1">
                    <button class="quiz-option" data-correct="true" data-explain="Every byte is accounted for and the flattening is the point. The leading 04 is the group count, and each pair after it is a count and a valtype: two i32, one i64, one f32, three i32. That is seven locals in four groups, and the local numbering is the flattening, so local 0 and 1 are i32, local 2 is i64, local 3 is f32, and locals 4, 5 and 6 are i32. The source that produced this had six local declarations, because two adjacent i32 declarations merged into the first group of two. A reader assuming one group per declaration would expect six groups, read the 04 as a count of six, and then start consuming pairs from the instruction stream, so every subsequent field would be wrong. The general habit is to decode a run-length structure by accumulating counts, never by assuming one entry per thing you thought you wrote." onclick="checkQuiz('quiz-wasm-code-1', this)">Four groups, seven locals, types <code>i32 i32 i64 f32 i32 i32 i32</code> in order. A reader expecting one group per declaration would read <code>04</code> as four and mis-number the locals from the second group onwards</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the off-by-the-group-size error, and it is a different mistake from the one described. There are four groups, not six, so treating a group as one local undercounts rather than overcounts. And the first leading byte is the group count, not a local total, so reading it as a local count skips the four (count, valtype) pairs entirely and lands in the instruction stream. The right arithmetic is to add up the counts: two plus one plus one plus three." onclick="checkQuiz('quiz-wasm-code-1', this)">Six groups and six locals, because there are six <code>(local ...)</code> declarations, and the reader is correct to disagree</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing an interpreter. A function takes one <code>i32</code> parameter and your test suite passes everything. One function in one module reports the wrong value for some inputs, and the module is otherwise fine: the right arity, the right body size, and every other function correct. The function declares <code>(local i64)</code> and <code>(local i32)</code>, so its local table is <code>02  01 7e  01 7f</code>. What is the most likely defect, and what would the evidence look like if you were wrong?</p>
                <div class="quiz" id="quiz-wasm-code-2">
                    <button class="quiz-option" data-correct="true" data-explain="The pattern is narrow and the evidence is unusually clean. Only one function is affected, it is the one with more than one local declaration group, and the group table here is the smallest case that can go wrong: two groups of one local each, so treating a group as a local happens to be correct and the failure needs a different explanation, whereas treating a group as the count of locals inverts the table and shifts every index. Reading 02 as a local count and then 01 7e as one local gives two locals where there are two, so the arity check passes, the type check is done against the wrong table, and the interpreter reads a valtype out of the instruction stream for anything past the first local. That produces exactly the observed signature: correct arity, correct body size, correct behaviour everywhere else, wrong values in one place. The confirming experiment is to hand the module to wasm-validate, which reads the local table as specified and will name the mismatch; and the second is to log the resolved type for every local.get in the failing function, where the first declared local will come back as a plausible but incorrect type." onclick="checkQuiz('quiz-wasm-code-2', this)">Your local resolver is reading the group table as one local per group instead of one per unit of the run length, so the types are shifted. The confirming evidence is that the failure is confined to functions with more than one group, and that <code>wasm-validate</code> accepts the module your interpreter misreads</button>
                    <button class="quiz-option" data-correct="false" data-explain="The symptom is wrong values rather than a wrong type, and an i64/i32 confusion would tend to corrupt the arithmetic in a way that is obvious across many inputs rather than intermittently. It is also ruled out by the table itself: 01 7e and 01 7f are unambiguous, and a reader that misread 7e as 7f would be wrong about the first declared local in a way that has nothing to do with group counting. Worth keeping in mind as a second candidate, but the run-length encoding is the thing this course has just shown is easy to get wrong." onclick="checkQuiz('quiz-wasm-code-2', this)">The i64 local is being truncated to 32 bits somewhere in your value representation, and inputs above 2^31 wrap</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when one function in a large module behaves differently, look for what makes it structurally different rather than what makes it numerically unusual. Group count, local count and type count are three different numbers, and conflating them is silent.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The run-length local table is the first genuinely clever encoding in the format, and it is worth comparing with the two other run-length schemes in this collection. <a href="/courses/coff/lessons/coff-symbol-table">The COFF symbol table</a> uses an auxiliary record to mean "more symbols of the same kind follow" &mdash; a <code>NumberOfAuxSymbols</code> count, exactly analogous to a local group. And <a href="/courses/elf/lessons/section-header-table">ELF's group and symbol tables</a> use the same trick for a different reason, to avoid a second pass.</p>
                <p>What WebAssembly's version does that COFF's does not is compress the <em>type</em> as well as the repetition. COFF's auxiliary records distinguish a section symbol from a weak external from a file symbol; they do not say "ten more integers follow". So the WebAssembly scheme is a more aggressive encoding, and the cost is the one this concept keeps returning to: <strong>every consumer must decompress before it can do anything, and the compression is only valid within a run.</strong></p>
                <p>The order-preservation point connects to <a href="/courses/wasm/lessons/wasm-types">the type section</a> and to <a href="/courses/coff/lessons/coff-comdat-linking">the COMDAT checksum</a>. In both cases the format is optimising bytes while guaranteeing that an unrelated property stays fixed &mdash; here the local numbering, there the fact that two identical sections really were identical. A format that let an encoding change what a number <em>means</em> would not be a format; the compression is only allowed to be invisible, and a producer that reorders to compress better has produced a different module.</p>
                <p>One thing is still missing from the body, and it is the thing the next concept covers: the instruction stream itself. <code>local.get 1</code> and <code>end</code> have appeared in this concept only as bytes to be skipped over, and an opcode encoding is the one part of the format where a compact scheme would be most valuable and most dangerous &mdash; a dense one-byte opcode space means no room for extensions, which is exactly why the format kept the top four bits for a prefix and spent the recent proposals making that prefix do more work.</p>
                <p>Next: <a href="/courses/wasm/lessons/wasm-instructions">Instruction Encoding</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-globals">Previous: Globals</a></span>
                <span><a href="/courses/wasm/lessons/wasm-instructions">Next: Instruction Encoding</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
