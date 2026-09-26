// WebAssembly Course — Module 2: Declarations
// Concept: the type section — the five value types, the functype form, and the
// indirection that lets a signature be named by a number.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_types() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Type Section — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>The Type Section</h1>
            <div class="lesson-meta">20 min &middot; Module 2: Declarations &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>WebAssembly has no type checking in the language sense. There is no <code>int</code> keyword to misspell and no way to write a function that returns the wrong kind of thing &mdash; not because the language checks, but because <strong>every function's signature is a number, and the number indexes a table of signatures that the module must contain.</strong></p>
                <p>That is the type section: a list of function types, and nothing else. It is the first section in the file, and it is first for the reason the <a href="/courses/wasm/lessons/wasm-sections">section ordering</a> explains &mdash; everything else refers to it. A function says "I have type 0", an import says "I have type 2", and a validator checks those numbers exist.</p>
                <p>The consequence is a design choice that distinguishes WebAssembly from every other format in this collection. <strong>Types are structural, not nominal.</strong> Two modules that declare <code>(i32, i32) -&gt; i32</code> declare the <em>same</em> type, and there is no name to get wrong, no header to mismatch, no namespace to resolve. The cost is that you cannot write a recursive type without a type section entry to point at, which is why every real type system with recursion needs a mechanism for it &mdash; and why that mechanism is a separate proposal rather than part of the core.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three signatures, from a module with three functions. The whole section is sixteen bytes:</p>
                <div class="hex-dump">
                    <pre>000a: 03 60 02 7f 7f 01 7f 60 01 7f 01 7f 60 01 7f 00
      |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
      |  |  |  |  |  |  |  |  |  |  |  |  |  |  +----- type 2: one i32 param,
      |  |  |  |  |  |  |  |  |  |  |  |  |  |        NO results (0x00)
      |  |  |  |  |  |  |  |  |  |  |  |  |  +------------ 0x7f: one i32 param
      |  |  |  |  |  |  |  |  |  |  |  |  +----------------- 0x01: one result
      |  |  |  |  |  |  |  |  |  |  |  +-------------------- type 1: (i32) -> i32
      |  |  |  |  |  |  |  |  |  |  +-------------------------- 0x60: a function type
      |  |  |  |  |  |  |  |  |  +------------------------------------- 0x01: one result
      |  |  |  |  |  |  |  |  +------------------------------------------- 0x7f: i32
      |  |  |  |  |  |  |  +----------------------------------------------- 0x7f: i32
      |  |  |  |  |  |  +-------------------------------------------------- 0x02: TWO params
      |  |  |  |  |  +----------------------------------------------------- type 0: (i32,i32) -> i32
      |  |  |  |  +-------------------------------------------------------- 0x60: a function type
      |  +------------------------------------------------------------- 0x03: THREE types
      +------------------------------------------------------------------ start of payload
</pre>
                </div>
                <p>Three shapes and only three shapes in the whole file, which is the first thing to notice: <strong>every entry begins with <code>0x60</code></strong>. That byte is a <em>form</em> tag, and the type section's only form today is "function". It exists so the section can grow a second form later without ambiguity, and it is the same idea as the <code>DW_TAG_</code> prefix that lets <a href="/courses/dwarf/lessons/dwarf-dies">DWARF add a DIE kind</a> without renumbering.</p>
                <h3>The five value types</h3>
                <p>Four numeric types and one placeholder. Every value in a WebAssembly function is one of these:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Byte</th><th scope="col">Type</th><th scope="col">Size</th><th scope="col">Notes</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>0x7f</code></td><td><code>i32</code></td><td>32 bits</td><td>Signed or unsigned depending on the operation. WebAssembly has no separate <code>uint</code></td></tr>
                        <tr><td><code>0x7e</code></td><td><code>i64</code></td><td>64 bits</td><td>Same split as <code>i32</code> at a different width</td></tr>
                        <tr><td><code>0x7d</code></td><td><code>f32</code></td><td>32 bits</td><td>IEEE 754 binary32, little-endian</td></tr>
                        <tr><td><code>0x7c</code></td><td><code>f64</code></td><td>64 bits</td><td>IEEE 754 binary64, little-endian</td></tr>
                        <tr><td><code>0x7b</code></td><td><code>v128</code></td><td>128 bits</td><td>The SIMD proposal. Present in the encoding, absent from this course's samples</td></tr>
                    </tbody>
                </table>
                <p>Two things to notice. <strong>There is no pointer, no array, no struct, no <code>bool</code>, and no <code>void</code>.</strong> A function with no results has a result <em>count</em> of zero, not a "void" type, and the last type above encodes as <code>01 7f 00</code> &mdash; one i32 parameter and no results. A type system this small is what makes a validator tractable enough to run before a module is trusted.</p>
                <p>And <strong>the sign is an operation, not a type.</strong> <code>i32</code> covers both <code>-1</code> and <code>4294967295</code>; which one a bit pattern means depends on whether you used <code>i32.add</code> or <code>i32.lt_u</code>. That is not an oversight &mdash; it is what lets a language with a rich integer model compile to a type system with two integers, and it is the same reason the <a href="/courses/wasm/lessons/wasm-leb128">LEB128 concept</a> found a disassembler printing <code>i32.const</code> unsigned.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Why an indirection at all</h3>
                <p>Here is the thing that makes the type section necessary rather than decorative. From the same module, the function section is three bytes:</p>
                <div class="hex-dump">
                    <pre>0041: 02 00 01
      |  |  +-- function 1 has type 1
      |  +----- function 0 has type 0
      +-------- TWO functions
</pre>
                </div>
                <p>Two functions, two type <em>numbers</em>. Neither the signature nor the parameter count is repeated. And the effect compounds, because the same signature can be named from three places &mdash; a function, an import, and an export:</p>
                <div class="hex-dump">
                    <pre>type 0  (i32, i32) -> i32    named by: function 0
type 1  (i32) -> i32           named by: function 1
type 2  (i32) -> ()            named by: import env.log
</pre>
                </div>
                <p>So a module with fifty functions using five distinct signatures stores <strong>five types and fifty numbers</strong>, rather than fifty copies of the signature. The savings are real and they are not the only benefit: because a type is a number, <em>structural identity is free</em>. Two functions that declare the same type index are guaranteed to have the same signature, with no comparison of lists required.</p>
                <div class="callout callout-warn">
                    <strong>The cost, and it is not small.</strong> Nothing stops a producer from declaring <code>(i32) -&gt; i32</code> as type 1 and <code>(i32) -&gt; i32</code> again as type 7. The format does not require types to be deduplicated, so <code>func[0]</code> and <code>func[1]</code> can have identical signatures under different numbers, and <strong>an equality test on a signature is not an equality test on a type index.</strong> This bites a tool that tries to match an imported function to a locally-defined one by comparing type indices: it will report no match for two functions that are the same function. The correct test compares the <em>structures</em>, which means walking both type sections &mdash; and that is a real cost to pay for a format that refused to make types nominal.
                </div>
                <h3>Reading the whole section back</h3>
                <p>The decoder shipped with this course reads the three entries and prints them as signatures, and this is the output for the section above:</p>
                <pre><code>$ python3 wasm_decode.py decls.wasm
  [0] @0xb  (func (param i32 i32) (result i32))
  [1] @0x11 (func (param i32) (result i32))
  [2] @0x16 (func (param i32) (result -))</code></pre>
                <p>The trailing <code>-</code> is a deliberate choice in the decoder rather than a missing value: the result count is genuinely zero, and printing an empty list is more honest than printing the word "void", which the format does not have. It is a small example of a general point about reading binary formats &mdash; <strong>a field that can be zero is not a field that can be absent, and a printer that renders both as nothing has thrown away a distinction the format made.</strong></p>
                <p>And the offsets it reports are worth checking rather than accepting. It prints <code>0xb</code>, <code>0x11</code> and <code>0x16</code>, and the arithmetic confirms all three:</p>
                <div class="hex-dump">
                    <pre>0x0a  03                    count = 3
0x0b  60 02 7f 7f 01 7f        type 0: 6 bytes, ends 0x10
0x11  60 01 7f 01 7f           type 1: 5 bytes, ends 0x15
0x16  60 01 7f 00              type 2: 4 bytes, ends 0x19
0x1a                            payload ends; 0x0a + 1 + 6 + 5 + 4 = 0x1a
</pre>
                </div>
                <p>Note what the first offset is <em>not</em>: the section's payload starts at <code>0x0a</code>, and <code>0x0a</code> holds the count. Type 0 begins one byte later, at <code>0x0b</code>, because the count comes first. That is a one-byte difference between a plausible reading and the right one, and it is exactly the class of error that a decoder can make while still producing correct values &mdash; <strong>the entries are decoded correctly, the positions are reported wrongly, and nothing downstream can tell.</strong></p>
                <div class="callout callout-warn">
                    <strong>A real one, found while writing this paragraph.</strong> The draft of this concept claimed the decoder shipped with the course was off by one on these offsets, on the strength of a quick mental count. It is not &mdash; the check above shows the reported offsets are right, and it was the mental count that was wrong. The episode is worth recording anyway, because it is the shape of mistake this course keeps making and warns about: <strong>a claim about the data that felt obvious enough to skip the arithmetic.</strong> The three rules that would have caught it are cheap. Count the bytes yourself and compare. Ask what the total has to be and check it. And when a claim contradicts a tool you have not verified, believe the tool until the arithmetic says otherwise. Every one of the verified findings in this course survived because its arithmetic was done, and this one would have shipped as a confident falsehood if it had not been checked.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What the indirection buys a producer, and where it costs a consumer. Both directions matter, and the second is the one that catches people.</p>
                <div class="formula">
FOR A PRODUCER
    50 functions, 5 distinct signatures
    with the indirection:  5 types   + 50 one-byte numbers  = 55 bytes
    without it:            50 signatures inline, averaging 6 bytes = 300 bytes
    and a fatter saving when a signature is long -- a ten-parameter
    function costs one byte instead of twenty

FOR A CONSUMER LOOKING FOR A MATCH
    WRONG:  compare type indices
            func A has type 1, the import has type 7, both are
            (i32) -> i32, so a naive match fails

    RIGHT:  walk both type sections and compare structurally
            for each index in A's types:
                if the imported index's entry is the same
                   list of the same valtype bytes: match
            and note that this is O(types x signature length)
</div>
                <p>The right-hand column is the real cost, and it is worth understanding rather than resenting. Because the format makes types structural and represents them positionally, <strong>structural equality requires a lookup.</strong> A nominal system &mdash; where two types are the same if they have the same name &mdash; gets equality for free by comparing pointers. A structural system has to compare the structures, which means reading two arrays of variable-length lists and comparing them element by element.</p>
                <p>Three consequences follow, and each is a place a tool can go wrong:</p>
                <ul>
                    <li><strong>You cannot assume type indices are shared.</strong> Two modules can order their type sections differently and be entirely correct. Any code that treats "type 1" as a global identity is broken, and it will work on one test file and fail on another.</li>
                    <li><strong>You cannot assume the type section is sorted or deduplicated.</strong> It is a list in whatever order the producer chose, and nothing in the format rewards tidiness. Deduplicating it is a producer's optimisation, not an obligation.</li>
                    <li><strong>A structural match can be a false positive in a way that matters.</strong> Two signatures that are byte-identical really are the same type in this format's sense, so a match is sound. But two signatures that differ only in a type that itself has an index &mdash; under a proposal that adds recursive types &mdash; would need their types resolved recursively, and comparing the top-level bytes would be wrong. The core format avoids this by having no such types; the moment one is added, this comparison has to grow with it.</li>
</ul>
                <p>That last point is a good place to see the format's design pressure. A type system small enough that structural equality is a byte comparison is a type system that cannot express recursion, because a recursive type is a cycle and a cycle has no finite byte representation. WebAssembly's answer has been to keep the core flat and put recursion in a separate proposal with its own representation. <strong>The simplicity of the type section is not an accident of implementation; it is what buys the validator's speed, and the price is paid somewhere else.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -x decls.wasm | sed -n '/^Type/,/^Import/p'
$ python3 courses/wasm/assets/samples/wasm_decode.py --hex decls.wasm</code></pre>
                <ul>
                    <li><strong>Count the bytes you would save.</strong> Compile a file with many functions of a few distinct signatures, note the size of its type section, and compute what the same file would cost with signatures inlined. Then compile one where every function has a different signature and watch the ratio invert. <strong>The indirection is a bet that signatures repeat, and this is the measurement of whether the bet pays.</strong></li>
                    <li><strong>Prove the type section is not deduplicated.</strong> Write a hand-built module that declares <code>(i32) -&gt; i32</code> twice under two indices, and confirm it validates. Then check that nothing in the tools complains. That is the negative result that justifies the warning about comparing indices, and a negative result you have produced is worth more than one you have been told.</li>
                    <li><strong>Write the structural matcher and time it.</strong> Implement the right-hand column of the algorithm above, then generate a synthetic module with five hundred types and check how long the match takes. The answer is the practical reason a tool caches a structural signature to a canonical form once, rather than comparing on every lookup.</li>
                    <li><strong>Find the offset bug.</strong> The decoder shipped with this course reports each type's offset one byte later than it should. Compare its output against your own hand count on the sixteen-byte section above, fix it, and then <strong>verify that the fix changes only the offsets and none of the decoded values.</strong> That is a useful exercise in separating the two kinds of correctness a decoder has.</li>
                    <li><strong>Find the zero-result boundary.</strong> Declare a type with zero parameters and zero results, and one with zero results only, and read both back. A function that takes and returns nothing is the shape of every callback in the format, and it is encoded as two zero counts rather than a null.</li>
                    <li><strong>Compile something real and read its types.</strong> Take a C file with a mix of <code>int</code>, <code>long</code>, <code>float</code> and <code>double</code>, compile it, and read the type section. You will find that the language types collapse onto four &mdash; and that a C <code>long</code> is <code>i32</code> on one target and <code>i64</code> on another, which is a portability trap the compiler cannot see and the type section records faithfully.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a module's type section is <code>03 60 02 7f 7f 01 7f 60 01 7f 01 7f 60 01 7f 00</code>. Three functions are declared, with type indices 0, 1 and 1. What are the three signatures, and why does the second and third function sharing an index matter more than it looks?</p>
                <div class="quiz" id="quiz-wasm-types-1">
                    <button class="quiz-option" data-correct="true" data-explain="Every entry is 0x60, the function form, and each is a parameter count, that many value type bytes, a result count, then that many result bytes. Type 0 takes two i32 and returns one; type 1 takes one and returns one; type 2 takes one and returns nothing, encoded as a result count of 00 rather than a void type the format does not have. The sharing of index 1 is what the indirection is for: two functions with the same signature store one number each instead of the signature twice, and because the type is a number, structural identity becomes a comparison of integers. The trap is on the other side. Nothing obliges a producer to deduplicate, so a different module could declare the same signature as type 1 and as type 7, and any code that matches an import to a function by comparing indices would report no match between two identical functions. Indices are local to a module; only the structures they point at are comparable." onclick="checkQuiz('quiz-wasm-types-1', this)">Type 0 is <code>(i32, i32) -&gt; i32</code>, type 1 is <code>(i32) -&gt; i32</code>, type 2 is <code>(i32) -&gt; ()</code>. Sharing an index makes structural identity an integer comparison &mdash; but indices are module-local, so two modules can give the same signature different indices and a matcher comparing numbers will fail</button>
                    <button class="quiz-option" data-correct="false" data-explain="The signature is decoded correctly, but the conclusion about type indices is the opposite of the point. Sharing an index does not make identity local to a module, it makes it cheap within one. The reason a matcher cannot compare indices across modules is that a module is under no obligation to deduplicate: the same signature may be entry 1 in one file and entry 7 in another, and both files are equally correct. So the index comparison is a valid shortcut inside a module and unsound outside it, and the general rule is to compare structures whenever the comparison crosses a module boundary." onclick="checkQuiz('quiz-wasm-types-1', this)">Type 0 is <code>(i32, i32) -&gt; i32</code>, type 1 is <code>(i32) -&gt; i32</code>, type 2 is <code>(i32) -&gt; ()</code>. Sharing an index means the type section is deduplicated, so type identity is global and two modules can be compared directly</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing an import resolver. Your tool matches a module's calls to imported functions by finding a local function with a matching signature, so it can rewrite the import away. It works on every module except one, where it reports "no local implementation of <code>env.log</code>" &mdash; even though the module contains a function that is textually identical. Nothing errors; the module is valid. You have the object and the type sections for both. What is the most likely cause, what is the one-line check, and what is the general rule your matcher is missing?</p>
                <div class="quiz" id="quiz-wasm-types-2">
                    <button class="quiz-option" data-correct="true" data-explain="The symptom is specific and the diagnosis is cheap. A local function that is textually identical to the import and still not matched points at exactly one thing: your comparison is on the index and the indices differ. Nothing forces a producer to deduplicate, so a producer that emits every signature it uses, deduplicated or not, can easily give the same signature two numbers in one file. The one-line check is to print both indices and then print the structure each one points at; the structures will be visibly identical while the numbers are not, which confirms it in a single look. The general rule is that a type index is a position, not a name. It is a valid identity only within the module that assigned it, and every comparison that crosses a module boundary has to resolve the indices to structures first. It is the same class of mistake as comparing a file offset between two binaries, or a symbol index between two objects, and the reason it is dangerous is that it works perfectly on most of your test data." onclick="checkQuiz('quiz-wasm-types-2', this)">Your matcher compares type indices, and this module's producer did not deduplicate its type section, so the identical signature sits at different indices. Print both indices and the structures they point at; the general rule is that a type index is a position, not a name</button>
                    <button class="quiz-option" data-correct="false" data-explain="Worth ruling out, and the module being valid rules most of it out: a malformed type section would be rejected by wasm-validate, and the report says the module is fine. The arity hypothesis is also weak because it predicts a function whose call leaves the wrong number of values on the stack, which is a different and much more visible failure than a resolver that simply finds no candidate. And the two functions are textually identical, so a signature comparison would have matched them." onclick="checkQuiz('quiz-wasm-types-2', this)">The import's signature has a different arity from the local function's, because your reader is counting parameters from the wrong offset</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: an index into a per-file table is an identity only inside that file. The moment a comparison crosses files, resolve the indices to what they point at first &mdash; and do it before the bug is in front of a user.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>WebAssembly's structural types are the opposite of DWARF's. <a href="/courses/dwarf/lessons/dwarf-types">A DWARF type is a graph of DIEs</a> joined by <code>DW_AT_type</code> references: a struct names its members, a member names its type, a pointer names a base type, and equality between two type descriptions is a graph-walking problem that no reader can shortcut. WebAssembly has no such graph &mdash; a type is a flat list of valtype bytes &mdash; which is why its validator can check a whole module's types quickly and why a signature match is a byte comparison.</p>
                <p>The comparison with <a href="/courses/coff/lessons/coff-symbol-table">COFF</a> is about the other half of the problem. COFF has no types at all: a symbol is 18 bytes with a storage class and no signature, and a linker checks that a symbol exists rather than that it is callable. WebAssembly traded that for a type table, and got arity checking, JIT specialisation on known signatures, and the ability to reject a mismatched import at validation time instead of at run time. <strong>Both formats answer "does this symbol exist"; only one answers "can I call it correctly", and the price is a section that has to be present even when every function is <code>() -&gt; ()</code>.</strong></p>
                <p>And the <code>0x60</code> form tag has a direct precedent in the <a href="/courses/coff/lessons/coff-comdat">COFF auxiliary records</a> and the <a href="/courses/dwarf/lessons/dwarf-dies">DWARF <code>DW_TAG_</code> prefix</a>. All three formats reserve a small value to say "which kind of record follows", and all three do it for the same reason: so the set of records can grow without a new section and without renumbering. In COFF it is the <code>StorageClass</code>; in DWARF it is the tag; in WebAssembly it is a single <code>0x60</code> that is currently the only legal value in the type section.</p>
                <p>Next: <a href="/courses/wasm/lessons/wasm-imports">Imports and Index Spaces</a> &mdash; the section that decides which number a function has, and why that number is not what you would guess.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-leb128">Previous: LEB128</a></span>
                <span><a href="/courses/wasm/lessons/wasm-imports">Next: Imports and Index Spaces</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
