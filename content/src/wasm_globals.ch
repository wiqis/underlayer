// WebAssembly Course — Module 2: Declarations
// Concept: the global section — mutability, the initialiser that is an
// expression rather than a value, and what a disassembler prints.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_wasm_globals() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Globals and Initialisers — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson wasm-lesson">
            <a href="/courses/wasm" class="back-link">Back to course</a>
            <h1>Globals and Initialisers</h1>
            <div class="lesson-meta">19 min &middot; Module 2: Declarations &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A global is a named value that lives for the module's whole life. It is the closest thing WebAssembly has to a static variable, and the reason the format has one at all is a specific and rather elegant constraint: <strong>a module may not modify anything it did not create</strong>. No global, no write to a read-only import; a global it declared, and then only if it declared that global mutable.</p>
                <p>That constraint is what makes a WebAssembly module safe to run next to code it does not trust. There is no writable memory that two modules share unless both agreed to share it, and a module cannot scribble on an imported memory or a stack pointer belonging to its host. The global section is where that rule is expressed, and the mutability bit is the whole of it.</p>
                <p>The second thing this section teaches is a shape you have not met anywhere else in a binary format: <strong>an initialiser that is an expression, not a value</strong>. Every other section stores data. This one stores a tiny program &mdash; an opcode stream, terminated by its own end marker &mdash; because a global's initial value may depend on another global. And that is the reason a value-looking field has to be walked rather than read, which is a trap worth studying.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two bytes of type information, then an expression that produces the value:</p>
                <div class="formula">
global section:
    count                       how many globals follow

global, repeated `count` times:
    valtype                     i32 / i64 / f32 / f64 / v128
    mut                         ONE byte: 0x00 = immutable, 0x01 = mutable
    init                        a CONSTANT EXPRESSION
</div>
                <p>The <code>mut</code> byte is a boolean written as a whole byte, not a bit inside a flags word. <strong>It has exactly two legal values, and they are 0 and 1</strong> &mdash; this is the one place in the core format where a flag really is an enumeration, which is why the previous concept's warning about limits flags does not apply here. The distinction is worth holding precisely: limits flags have independent bits that happen to combine into small numbers, while this is a single yes/no and a reader that accepted <code>0x02</code> would be accepting an illegal module.</p>
                <h3>What a constant expression is</h3>
                <p>An expression in the WebAssembly sense is a sequence of instructions operating on a stack. A <em>constant</em> expression is the tiny subset that can be evaluated at load time rather than at run time, and it is what a global's initialiser must be:</p>
                <div class="hex-dump">
                    <pre>41 xx 0b              i32.const xx ; end
42 xx 0b              i64.const xx ; end
43 xxxx 0b            f32.const (4 bytes, little-endian)
44 xxxxxxxx 0b        f64.const (8 bytes, little-endian)
23 xx 0b              global.get xx ; end
d0 xx 0b              ref.null &lt;heaptype> ; end
d2 xx 0b              ref.func &lt;funcidx> ; end
</pre>
                </div>
                <p>Every one ends with <code>0x0b</code>, the same byte that ends a function body. That is not a coincidence and not a shared implementation convenience: <strong>the specification defines one <code>end</code> opcode used by both</strong>, and the body framing in <a href="/courses/wasm/lessons/wasm-code">the code section</a> is what distinguishes the two uses. A global's initialiser is a function body with no locals, no parameters, and a restricted opcode set.</p>
                <p>And that restricted set is why the initialiser can reference another global: <code>global.get</code> is in the constant subset, so</p>
                <div class="formula">
(global $a i32 (i32.const 10))
(global $b i32 (global.get 0))    // = $a = 10
</div>
                <p>works. What is <em>not</em> in the subset is arithmetic. There is no <code>i32.add</code> in a constant expression, so a global cannot be defined as "twice another global" &mdash; the compiler has to emit a <code>global.get 0</code> plus a <code>global.get 0</code> and add them in the code that uses it. <strong>The subset is chosen so that a reader can evaluate it with a stack of a known small size and no possibility of looping, branching, or trapping.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>A module with eight globals covering the full signed range of both integer types. Eleven bytes of section, and every byte is visible:</p>
                <div class="hex-dump">
                    <pre>0045: 08                    EIGHT globals
      |  |
      |  +-- the sixth:  7e 01 42 80 80 80 80 7f 0b
      |          |     |  |
      |          |     |  +-- i64.const, the value, then end
      |          |     +---- 0x01: MUTABLE
      |          +---------- 0x7e: i64
      +--------------------- 0x45: payload starts here
</pre>
                </div>
                <p>Read the last entry in full, because it is the one that shows why the initialiser has to be walked:</p>
                <div class="hex-dump">
                    <pre>  7e                 valtype: i64
  01                 mutable
  42                 opcode: i64.const
  80 80 80 80 7f     the operand: a 5-byte SIGNED LEB128
  0b                 end
</pre>
                </div>
                <p>That operand is <code>-1</code>. And a decoder that assumes a constant expression is <code>opcode, one byte, end</code> reads <code>0x80</code> as the value, treats <code>0x80</code> as an opcode, and is already lost. The rule is simple and the discipline is what matters: <strong>an opcode stream is read until its terminator, never to a guessed length.</strong> This is the same trap as the data section's offset expressions, the same trap as a <a href="/courses/dwarf/lessons/dwarf-dies">DIE chain</a> that must be walked rather than sized, and the reason this course keeps finding it in a new place is that a length-prefixed container and a self-delimiting one look identical until one of them is variable-width.</p>
                <h3>What the two reference tools print, and why they differ</h3>
                <p>Here is the same eight globals read by wabt's detail view, with the values my decoder recovers from the same bytes:</p>
                <div class="hex-dump">
                    <pre>  wabt -x                        my decoder
  global[0] init i32=0              i32.const 0 end
  global[1] init i32=42             i32.const 42 end
  global[2] init i32=-1             i32.const -1 end
  global[3] init i32=-1000000       i32.const -1000000 end
  global[4] init i32=2147483647     i32.const 2147483647 end
  global[5] init i32=-2147483648    i32.const -2147483648 end
  global[6] init i64=-1             i64.const -1 end
  global[7] init i64=9223372036854775807   i64.const 9223372036854775807 end
</pre>
                </div>
                <p>All eight agree. And the interesting part is that <strong>wabt gets this right in one subcommand and wrong-looking in another</strong>. The same three bytes <code>41 7f 0b</code> mean <code>i32.const -1</code>. Ask for details:</p>
                <div class="hex-dump">
                    <pre>$ wasm-objdump -x globs.wasm | grep 'global\[2\]'
   - global[2] i32 mutable=0 - init i32=-1        &lt;- signed, correct

$ wasm-objdump -d neg.wasm | grep '41 7f'
   000049: 41 7f    | i32.const 4294967295      &lt;- UNSIGNED
</pre>
                </div>
                <p>One tool, two subcommands, two presentations of the same two bytes. The detail view is interpreting the operand as the <em>value of an initialiser</em> and printing it signed; the disassembler is printing an <em>instruction operand</em> and treating it as the 32-bit bit pattern. Both are internally consistent, and one of them will mislead anyone who copies a number out of it.</p>
                <div class="callout callout-warn">
                    <strong>Why the unsigned display is the dangerous one.</strong> A disassembler prints a bit pattern because that is what a disassembler is for &mdash; you are looking at bytes, and a byte has no sign. A detail view prints a value because you are looking at a program, and a program's <code>i32</code> initialiser is a signed integer. The wrong one to trust is the disassembly, because it is the one people read when they want to know what a number <em>is</em>. If you copy <code>4294967295</code> out of a disassembly into a program and compare it to a source constant <code>-1</code>, the comparison fails and the number of plausible explanations is large. <strong>When a tool prints a signed value in two different ways, the difference is not a bug in either tool; it is two different questions being answered, and the reader has to know which question was asked.</strong>
                </div>
                <h3>Mutability, and what it actually protects</h3>
                <p>The mutability bit is the module's own declaration about whether it will write to a global, and it is enforced by the validator rather than by convention. Three consequences follow, and the third is the one that makes the rule worth having:</p>
                <ul>
                    <li><strong>An immutable global can be constant-folded.</strong> A reader that has evaluated the initialiser knows the value forever, so <code>global.get 0</code> on an immutable global can be replaced by a literal. A mutable one cannot, because a <code>global.set</code> might have changed it. <strong>This is why the mutability bit affects optimisation, not just permission.</strong></li>
                    <li><strong>An imported global is a capability, and its mutability is a contract.</strong> If the module declared an import mutable, the host is agreeing that the module may write it. A host that hands over a memory's length or a stack pointer will declare that import immutable, and the validator will reject a module that tries to set it.</li>
                    <li><strong>A global cannot alias a memory, and this closes the whole class of attack.</strong> A global holds a number. It is not a pointer the runtime follows, and there is no way to make a global refer to memory. So a module cannot launder a memory address into something the host trusts, cannot grow a buffer by rewriting a size it was given, and cannot get a pointer into a position where a later bounds check was assumed. <strong>The only writable state a module has is memory it declared, and the only way to name it is a table or memory index the validator has already checked.</strong></li>
                </ul>
                <p>That third point is the security argument for the whole feature, and it is worth seeing it against a native platform. In <a href="/courses/pe/lessons/pe-imports">a PE image</a> a global variable is an address, and the linker will happily point one at a function, another at a data object, and a third at an import thunk &mdash; three "globals" with three unrelated meanings distinguished only by convention. WebAssembly makes all three of those explicit and checked, and pays for it with a global that can only be a number.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Evaluating an initialiser, which is the operation a reader does once per global at load time, and the reason it cannot simply be "read the bytes and interpret them as a value":</p>
                <div class="formula">
eval_const_expr(module, offset) -> (value, type, bytes_consumed):

    stack = []                       # a value stack, as an interpreter
    loop:
        opcode = read_u8()

        0x41: push i32 (read_sleb32)   # signed: 0x7f is -1, not 127
        0x42: push i64 (read_sleb64)
        0x43: push f32 (read 4 bytes, little-endian)
        0x44: push f64 (read 8 bytes, little-endian)
        0x23: push (module.globals[read_uleb].current_value)
        0xd0: push null (read heaptype)
        0xd2: push (ref to module.funcs[read_uleb])
        0x0b: RETURN (pop one value, and bytes_consumed)

        anything else: REJECT
            not a constant expression. The validator's error, and it
            is the one place a reader that skipped validation will
            silently accept something it must not.
</div>
                <p>Two details in that are the whole lesson. <strong><code>read_sleb32</code>, not <code>read_uleb32</code></strong> &mdash; the operand is a signed LEB128, so <code>0x7f</code> is <code>-1</code>, and a reader that reads it unsigned gets <code>127</code> for every <code>-1</code> in the file. And <strong><code>global.get</code> reads the value of an <em>earlier</em> global</strong>, which is legal only because the constant subset contains no arithmetic and no control flow, so the dependency graph over globals is acyclic by construction: a global can only read globals numbered below it, and reading a later one is a validation error.</p>
                <p>That acyclicity is a design choice, and it is load-bearing. A constant expression with <code>i32.add</code> in it could still be acyclic by the same argument, so the restriction is not strictly necessary &mdash; but restricting to leaf values makes the evaluation obviously terminating and the dependency obviously a DAG, and it is why a reader can evaluate globals in declaration order without a fixpoint loop. <strong>Choose the subset that makes the naive algorithm correct.</strong></p>
                <p>Now the failure that the naive algorithm invites, which is the most valuable thing in this concept because it is entirely silent. Suppose the reader treats an initialiser as a fixed four bytes &mdash; a plausible guess for "a value" before you think about the encoding:</p>
                <div class="hex-dump">
                    <pre>  correct:   7f 01 42 80 80 80 80 7f 0b     9 bytes, 5-byte operand
  naive:     7f 01 42 80 80 80 80            6 bytes read
            -> reports i64 = 0x80808080 = 2155905152
            -> the next global starts at 0x0b, which is 0x7f
            -> reads 0x7f as a valtype (i32), 0x0b as mutability (11!),
               then runs off into the instruction bytes

  and the worst part: the wrong value 2155905152 is a perfectly
  plausible i64. Nothing complains. The global is just wrong.
</pre>
                </div>
                <p>So the desynchronisation is caught eventually, but the <em>first</em> thing the reader gets wrong is a number that looks entirely reasonable, and if the module had no second global the desync would never happen at all &mdash; the reader would report one wrong value and stop. <strong>A decoder that cannot detect its own desync will report a confident wrong answer rather than an error, and the only defence is to decode each structure by the rules that structure has.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ wasm-objdump -x globs.wasm | sed -n '/^Global/,$p'
$ python3 courses/wasm/assets/samples/wasm_decode.py globs.wasm</code></pre>
                <ul>
                    <li><strong>Make the fixed-length reader and watch it lie.</strong> Write a small script that reads a global's initialiser as a fixed five bytes, and run it on <code>globs.wasm</code>. It will report a plausible wrong value for the 5-byte-LEB entries and a correct one for the 1-byte entries, and the pattern of which ones are wrong is itself the clue: <strong>the failures are exactly the entries whose operand is not one byte long.</strong> That is what a variable-width encoding looks like from the outside.</li>
                    <li><strong>Find the boundary where the encoding changes width.</strong> Emit <code>i32.const</code> with values 63, 64, 8191, 8192, and then the extremes, and record the operand length at each. 63 and 8191 are one byte; 64 and 8192 are two. <strong>The thresholds are the proof that the width is a function of the value and not a fixed field width</strong>, and finding them yourself is much stronger than being told.</li>
                    <li><strong>Chain globals.</strong> Write <code>$a = 10</code>, <code>$b = global.get $a</code>, <code>$c = global.get $b</code> and confirm all three initialise. Then try <code>$a = global.get $b</code> where <code>$b</code> is defined later, and see what the validator says. <strong>The error message names the cycle, which is more informative than it needs to be and worth reading.</strong></li>
                    <li><strong>Try to write an immutable global.</strong> Add <code>global.set 0</code> to a function that targets an immutable global, and read the validation error. Then make it mutable and confirm it validates. The mutability bit is checked, not advisory, and seeing the rejection is how you know the rule is real rather than documentation.</li>
                    <li><strong>Compare the two tools on the same value again.</strong> Run <code>wasm-objdump -x</code> and <code>wasm-objdump -d</code> over <code>neg.wasm</code> and write down, side by side, how each prints <code>41 7f</code>. Then state in one sentence which one you would trust for a value and which for a bit pattern. <strong>Getting that sentence right is the practical outcome of this concept.</strong></li>
                    <li><strong>See what a compiled language does with globals.</strong> Compile a C file with a genuine <code>static</code> variable and a constant, and read the resulting global section. An <code>int</code> that is never written becomes an immutable global; one that is written becomes mutable; and one the compiler can fold into its uses often does not appear at all. <strong>That last case is the constant-folding consequence made visible in a real toolchain output.</strong></li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a global's bytes are <code>7e 01 42 80 80 80 80 7f 0b</code>. What is its type, its mutability, and its value? And what would a reader that read the initialiser as <code>0x42</code> plus a single unsigned byte report?</p>
                <div class="quiz" id="quiz-wasm-globals-1">
                    <button class="quiz-option" data-correct="true" data-explain="The type is i64 and the mutability byte is 0x01, so the global is writable. The value is the signed LEB128 that follows the 0x42 i64.const opcode, and that operand is five bytes: 0x80 contributes no low bits and signals continuation, 0x7f in the final position contributes 127 shifted left by 28, and the sign bit of the final byte is what makes it negative. Decoded as signed it is -1, which is the classic all-ones pattern. A reader that assumed the operand was a single unsigned byte would read 0x80 as 128 and stop, then treat 0x80 as the next opcode, which is not a constant expression at all. So the two candidate wrong answers are 128, from a truncated unsigned read, and a desynchronised parse; the correct one requires reading five bytes as signed. The general habit is that a constant expression is walked to its 0x0b terminator and never sized." onclick="checkQuiz('quiz-wasm-globals-1', this)">An <code>i64</code>, mutable, initialised to <code>-1</code>. The naive reader gets <code>128</code> and then loses sync, because the operand is a 5-byte <em>signed</em> LEB128 that must be read to its end byte</button>
                    <button class="quiz-option" data-correct="false" data-explain="The unsigned reading is the trap this concept is about. 0x80 is not the value; it is the first byte of a five-byte encoding whose low seven bits happen to be zero and whose continuation bit is set. Read as a whole signed LEB128 the operand is -1, and the final byte's sign bit is exactly what distinguishes it. The count of bytes is what proves the point: a single unsigned byte would make the encoding pointless, since 0x7f would then have to be the value and the four following bytes would be unaccounted for." onclick="checkQuiz('quiz-wasm-globals-1', this)">An <code>i64</code>, mutable, initialised to <code>128</code>, because <code>0x42</code> is <code>i64.const</code> and the next byte is the operand</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a loader. A module's globals come out as: the first correct, the second correct, the third reporting <code>i64 = 2155905152</code> when the source says <code>-1</code>, and the fourth reporting a mutability of <code>11</code>. Everything after the third is garbage, and the module validated before you ran it. The third global's bytes are <code>7f 01 42 80 80 80 80 7f 0b</code>. What is the defect, why did validation not catch it, and what is the general rule for reading any field in this format that could be variable-width?</p>
                <div class="quiz" id="quiz-wasm-globals-2">
                    <button class="quiz-option" data-correct="true" data-explain="All three symptoms come from one cause, and the pattern in the evidence is what identifies it. The third global's value is wrong and the fourth's mutability is nonsense, so the parse position after the third global is wrong, not just the value. That points at a length problem rather than a decoding problem: the reader consumed a fixed number of bytes for the initialiser when the real encoding is variable-width. 2155905152 is 0x80808080, which is exactly the first four operand bytes read as a little-endian number, so the reader read four bytes instead of five. Validation did not catch it because validation is performed by a different component &mdash; the wasm-validate in the toolchain read the same bytes correctly and found a legal module. Your loader disagreed with the validator, and nothing told you. The general rule is that any field in a binary format which is variable-width, self-delimiting, or count-determined must be walked until its own terminator, and a reader that needs a total length must get it from the format's own framing &mdash; never from a guess about the field's size. The general habit is to add a position assertion after every structure you decode, checked against the enclosing section's end, because a desync caught at the section boundary is a clean error and a desync caught ten globals later is a mystery." onclick="checkQuiz('quiz-wasm-globals-2', this)">The reader sizes the initialiser instead of walking it, so it consumed four bytes of a five-byte signed LEB128 and the rest of the module is read from the wrong position. Validation was done by a different, correct reader &mdash; and the fix is a position assertion after every structure, checked against the section's declared end</button>
                    <button class="quiz-option" data-correct="false" data-explain="The sign hypothesis is the natural first guess and the arithmetic rules it out. 0x80808080 is positive as a signed value and 2155905152 is what you get from four literal bytes read little-endian, which no sign interpretation would produce. And a sign error would leave the parse position correct, so the fourth global's mutability of 11 would not happen. The evidence points at position, not at interpretation, and the way to tell those apart is to ask whether later fields are also wrong: if they are, it is a length problem." onclick="checkQuiz('quiz-wasm-globals-2', this)">The reader decodes the LEB128 as unsigned, so every negative initialiser is wrong; and it is applying a mutability check that is not in the specification</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: after decoding each structure, assert that your position matches what the enclosing section's framing says it should. That turns a silent desync into a clean error at the section boundary, and a desync at the section boundary is a bug you can find in one print statement.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The mutability bit is the WebAssembly answer to a question every executable format has to answer differently, and the three answers are worth comparing. <a href="/courses/elf/lessons/section-header-table">An ELF section's <code>SHF_WRITE</code> flag</a> is a property of a whole region, fixed at link time. <a href="/courses/coff/lessons/coff-characteristics">A COFF section's characteristics</a> work the same way. <a href="/courses/pe/lessons/pe-section-table">A PE section's <code>VirtualProtect</code> is mutable by default</a> and only becomes read-only if something asks. WebAssembly's answer is the most restrictive of the four: the <em>unit</em> of mutability is a single value, it is declared, and the default is read-only.</p>
                <p>That default matters more than it looks. A format where immutable is the default and mutable is something you have to ask for means a mistake is always in the safe direction, which is a property worth designing for. It is the same instinct behind the <a href="/courses/elf/lessons/program-header-table">ELF header's read-only program headers</a> preceding the writable ones, and behind a linker putting <code>.text</code> before <code>.data</code>.</p>
                <p>The constant-expression subset connects to <a href="/courses/pe/lessons/pe-base-relocations">PE base relocations</a>, which is the nearest thing in this collection to a limited computation at load time. A base relocation record says "add the image base to this address", and the set of them is fixed by the linker. WebAssembly's initialisers are the same idea generalised: a tiny declarative language whose only job is to produce a value before execution starts. The difference is that WebAssembly's is genuinely an <em>expression</em> with a stack, so it can reference other globals, where a relocation can only add a constant.</p>
                <p>And the walked-to-terminator discipline has now appeared in the element section, the data section, the global section, and every function body. That is four places in one small format where the same rule applies, which is the strongest argument in this course for treating "how do I know where this ends" as the first question to ask about any field. <a href="/courses/dwarf/lessons/dwarf-dies">DWARF's DIE chains</a> and <a href="/courses/pe/lessons/pe-resources">the PE resource directory tree</a> are the same shape in completely different formats, and a reader who has internalised it there will not have to relearn it here.</p>
                <p>Next: <a href="/courses/wasm/lessons/wasm-elements">the element and data sections</a>, where the eight element encodings come from, and then the object format the final module covers.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm/lessons/wasm-tables-memories">Previous: Tables, Memories and Limits</a></span>
                <span><a href="/courses/wasm/lessons/wasm-code">Next: The Code Section</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
