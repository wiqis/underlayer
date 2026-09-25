// DWARF Course — Module 3: DIEs, Types, Scopes, Locations and Frames
// Concept: DW_OP location expressions, and the stack machine that evaluates them.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_locations() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Location Expressions — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Location Expressions</h1>
            <div class="lesson-meta">21 min &middot; Module 3: DIEs, Types, Scopes and Locations &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A global variable has an address. A local variable does not: it lives at an offset from the stack pointer, and the stack pointer moves every time anything is pushed. So the number <code>rsp - 24</code> is not an address &mdash; it is an instruction for computing one, valid only for one function on one particular stack state.</p>
                <p>DWARF stores that instruction. A <strong>location expression</strong> is a tiny stack machine program, and evaluating it is how a debugger answers "where is this variable right now". Every value you have ever seen a debugger print for a local went through one of these.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>An expression is a byte string with a length prefix. The bytes are opcodes, and they run on a stack:</p>
                <ul>
                    <li><strong>Push a register's value:</strong> <code>DW_OP_reg0</code> through <code>DW_OP_reg31</code> are single bytes, one per machine register. This is how an optimised build says "this variable lives in a register" &mdash; and it is the normal case at <code>-O2</code>.</li>
                    <li><strong>Push a constant:</strong> <code>DW_OP_addr</code> followed by a machine address, <code>DW_OP_const1u</code> and friends, <code>DW_OP_litN</code> for small values.</li>
                    <li><strong>Push a value relative to something else:</strong> <code>DW_OP_bregN</code> pushes register <code>N</code>'s value plus a signed offset; <code>DW_OP_fbreg</code> pushes the frame base plus a signed offset.</li>
                    <li><strong>Combine:</strong> <code>DW_OP_plus</code> pops two and pushes the sum, <code>DW_OP_deref</code> pops an address and pushes what it points at.</li>
                    <li><strong>Finish:</strong> with exactly one value on the stack, that value is the variable's address. A <code>DW_OP_stack_value</code> opcode changes the meaning: the value left on the stack <em>is</em> the variable, not its address.</li>
                </ul>
                <div class="callout callout-warn">
                    <strong>Which stack machine?</strong> There are two, and they share opcode numbering in some ranges. The one used by <code>DW_AT_location</code> as an <code>exprloc</code> is the <em>expression</em> machine, whose <code>DW_OP_fbreg</code> is 0x91. The one used by <code>DW_AT_frame_base</code> is the <em>location</em> machine, where the same idea is <code>DW_OP_call_frame_cfa</code> = 0x9c. Reading a frame base with the expression machine gives you a frame-base-relative offset; reading a location with the location machine gives you something else entirely. Neither error raises anything.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The reference binary's <code>make_point</code>, every location it records, read out of <code>.debug_info</code> and confirmed against both reference readers:</p>
                <table>
                    <thead>
                        <tr><th scope="col">DIE</th><th scope="col">Attribute</th><th scope="col">Bytes</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>&lt;0x15c&gt;</code> subprogram</td><td><code>DW_AT_frame_base</code></td><td><code>9c</code></td><td><code>DW_OP_call_frame_cfa</code> &mdash; the frame base <em>is</em> the CFA</td></tr>
                        <tr><td><code>&lt;0x17d&gt;</code> parameter <code>x</code></td><td><code>DW_AT_location</code></td><td><code>91 5c</code></td><td><code>DW_OP_fbreg</code> with SLEB128 operand <code>0x5c</code> = <strong>-36</strong></td></tr>
                        <tr><td><code>&lt;0x189&gt;</code> parameter <code>y</code></td><td><code>DW_AT_location</code></td><td><code>91 58</code></td><td><code>DW_OP_fbreg</code> + SLEB128 <code>0x58</code> = <strong>-40</strong></td></tr>
                        <tr><td><code>&lt;0x195&gt;</code> variable <code>out</code></td><td><code>DW_AT_location</code></td><td><code>91 68</code></td><td><code>DW_OP_fbreg</code> + SLEB128 <code>0x68</code> = <strong>-24</strong></td></tr>
                    </tbody>
                </table>
                <p>Three details that are easy to get wrong and produce no error at all:</p>
                <ol>
                    <li><strong>The operand is SLEB128, signed.</strong> <code>0x5c</code> is not 92. As a signed LEB128 byte it is <code>0x5c - 0x80 = -36</code>, because the high bit is the sign flag. Reading these as unsigned gives offsets of 92, 88 and 104 bytes, which are in the caller's frame and will look like plausible garbage.</li>
                    <li><strong>Negative offsets are the normal case for parameters.</strong> The frame base is the canonical frame address, which the CFI establishes as <code>rsp + 8</code> on entry (see the next concept). Parameters were pushed <em>before</em> the call, so they sit at negative offsets from it.</li>
                    <li><strong>Two bytes is the floor.</strong> The length prefix is a ULEB128, so <code>2 byte block: 91 5c</code> means one opcode plus a one-byte operand. There is no fixed-size location field anywhere in the format.</li>
                </ol>
                <p>What the frame base is comes from the CIE, and the two halves of that belong to different concepts. From the reference binary's single CIE:</p>
                <pre><code>DW_CFA_def_cfa  reg=7, offset=8      "the CFA is rsp + 8"
DW_CFA_offset  reg=16, factored=-8 bytes   "the return address is saved at CFA-8"</code></pre>
                <p>So <code>DW_OP_call_frame_cfa</code> evaluates to <code>rsp + 8</code> at function entry, and parameter <code>x</code> is at <code>rsp + 8 - 36 = rsp - 28</code>. That is where a debugger actually reads it, and the arithmetic is the join between this concept and <a href="/courses/dwarf/lessons/dwarf-frames">the frames concept</a>.</p>
                <h3>The one-opcode case</h3>
                <p>At <code>-O0</code> almost every location is a <code>fbreg</code>, because nothing has been optimised. At <code>-O2</code> the common case is a single byte. From the <code>inline.c</code> build:</p>
                <div class="hex-dump">
                    <pre>&lt;2&gt;&lt;...&gt;  DW_AT_location : 91 00      DW_OP_fbreg 0        (offset zero)
&lt;2&gt;&lt;...&gt;  DW_AT_location : 91 18      DW_OP_fbreg +24
</pre>
                </div>
                <p>And from the same build, the first inlined instance's parameter:</p>
                <pre><code>DW_AT_location : 2 byte block: 91 0    (DW_OP_fbreg: 0)</code></pre>
                <p>A one-byte operand of <code>0x00</code> is <strong>zero</strong>, not 128. Signed LEB128 encodes zero as a single <code>0x00</code> byte, and this is the shortest possible <code>fbreg</code> expression. It is also the easiest to get wrong, because a reader that treats the operand as unsigned reads 128 and puts the variable in the caller's frame.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Evaluating <code>91 5c</code> by hand, in full, with no tool involved:</p>
                <ol>
                    <li>Read opcode <code>0x91</code>. That is <code>DW_OP_fbreg</code>: pop a SLEB128 operand, then push <em>frame base + operand</em>. The <code>DW_OP_bregN</code> and <code>DW_OP_regN</code> opcodes read a <em>register</em>; <code>fbreg</code> reads the frame base, which is itself whatever the function's <code>DW_AT_frame_base</code> expression evaluates to.</li>
                    <li>Read the operand byte <code>0x5c</code>. Its high bit is set, so this SLEB128 value continues &mdash; and the next byte would be needed. There is no next byte, so the value is complete and the sign bit is bit 6 of <code>0x5c</code>, which is set: <code>0x5c</code> is a negative number. Decoding a single-byte SLEB128: bit 6 set means negative, and the magnitude is <code>0x5c &amp; 0x3f = 28</code>, so the value is <code>28 - 64 = -36</code>.</li>
                    <li>So the stack now holds one value: <code>frame_base - 36</code>.</li>
                    <li>The expression has ended with exactly one value on the stack, and no <code>DW_OP_stack_value</code> appeared, so that value <strong>is the address</strong> of <code>x</code>.</li>
                    <li>Read 4 bytes there and interpret them as a signed 32-bit integer, because <code>x</code>'s <code>DW_AT_type</code> is <code>&lt;0x5d&gt;</code> = <code>int</code>.</li>
                </ol>
                <p>Now the general evaluation loop, which is all a debugger needs:</p>
                <div class="formula">
stack = []
for each opcode in the expression:
    if it pushes a register:   stack.push(read_register(n))
    if it pushes a constant:   stack.push(constant)
    if it is bregN / fbreg:    stack.push(base + signed_leb128())
    if it is plus/minus/etc:   stack.push(combine(stack.pop(), stack.pop()))
    if it is deref:            stack.push(read_memory(stack.pop()))
    if it is stack_value:      the remaining value IS the variable
address = stack.pop()          (if no stack_value was seen)
                </div>
                <p>And the two ways this goes wrong without an error. A reader that treats the SLEB128 operand as unsigned gets -36 as 92. A reader that forgets that <code>fbreg</code> is relative to the frame base rather than to <code>rsp</code> gets every location off by 8 on entry, and off by a different amount after every <code>push</code>. Both produce values that are the right size and entirely wrong, which is why the CFI in the next concept is not optional background &mdash; it is the other half of every location.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ readelf --debug-dump=info shape | grep -E 'DW_AT_(location|frame_base)'
$ readelf --debug-dump=frames shape | head -12</code></pre>
                <p>Experiments that make the stack machine concrete:</p>
                <ul>
                    <li><strong>Write an evaluator and test it on the real bytes.</strong> The decoder shipped with this course prints every location expression it decodes. Add an evaluator and check the 64-bit <code>-O0</code> build, where every expression is <code>fbreg</code> and every operand is negative. If your SLEB128 decoder is unsigned you will get offsets of 88, 92 and 104, and every one of them will be in the caller's frame.</li>
                    <li><strong>Compile the same function at <code>-O0</code> and <code>-O2</code> and diff the locations.</strong> At <code>-O0</code>: three <code>fbreg</code> expressions. At <code>-O2</code>: the parameters are often <code>DW_OP_regN</code> &mdash; one byte, opcode only, no operand &mdash; because the value is in a register. The <em>form</em> of the answer changed, and the DIE still exists.</li>
                    <li><strong>Find a <code>DW_OP_stack_value</code>.</strong> It appears in the optimised build for values the compiler has constant-folded into a register, where the register holds the value itself rather than a pointer to it. It is the one opcode that changes the meaning of the whole expression, and getting it wrong means printing an address instead of the value.</li>
                    <li><strong>Confirm the two stack machines.</strong> <code>DW_AT_frame_base</code> holds <code>9c</code> = <code>DW_OP_call_frame_cfa</code>, which is a <em>location</em> machine opcode. <code>DW_AT_location</code> holds <code>91</code> = <code>DW_OP_fbreg</code>, an <em>expression</em> machine opcode. Evaluated with the wrong table you get a wrong answer, not an error.</li>
                </ul>
                <p>And a check on your own arithmetic: the three parameters of <code>make_point</code> are at CFA-36, CFA-40 and CFA-44, and the CIE says the return address is at CFA-8. A 48-byte frame with the return address at the top and the arguments just below it is the shape you should expect for three four-byte arguments on x86-64. If your numbers do not produce that shape, one of the three decoders is wrong.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a parameter's <code>DW_AT_location</code> is the two bytes <code>91 5c</code>. Decode the operand and say what the expression computes.</p>
                <div class="quiz" id="quiz-dwarf-locations-1">
                    <button class="quiz-option" data-correct="true" data-explain="0x91 is DW_OP_fbreg, which pushes the frame base plus a signed operand. The operand is SLEB128, and 0x5c is a single-byte negative value equal to -36, not the unsigned 92. The expression ends with one value on the stack and no DW_OP_stack_value, so that value is the variable's address: frame base minus 36, which resolves to rsp + 8 - 36 at function entry." onclick="checkQuiz('quiz-dwarf-locations-1', this)"><code>DW_OP_fbreg</code> with operand <strong>-36</strong>: the variable is at <em>frame base minus 36</em>. The <code>0x5c</code> is signed, so it is -36 and not 92</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the single most common error in decoding these expressions, because the operand byte has its high bit set and an unsigned reader takes it at face value. Offset 92 lands in the caller's frame, which is a plausible-looking address of the right shape and the wrong value entirely." onclick="checkQuiz('quiz-dwarf-locations-1', this)"><code>DW_OP_fbreg</code> with operand <strong>+92</strong>, so the variable is 92 bytes above the frame base and is therefore a caller&rsquo;s local</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x91 is DW_OP_fbreg, not DW_OP_breg, and the distinction is the point: bregN is relative to a machine register, fbreg is relative to the frame base established by the function's DW_AT_frame_base, which here is the CFA at rsp + 8. Confusing the two puts every location off by a different amount after each push." onclick="checkQuiz('quiz-dwarf-locations-1', this)"><code>DW_OP_breg7</code> with operand <strong>-36</strong>: the variable is at <em>rsp minus 36</em>, since <code>0x91</code> is the register-relative form and register 7 is rsp</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your debugger is correct on the <code>-O0</code> build and prints garbage for every local in the <code>-O2</code> build. It still finds the right <em>variables</em> and the right <em>types</em> &mdash; only the values are wrong, and they are wrong in a way that looks like a plausible pointer. Your evaluator handles <code>DW_OP_fbreg</code>, <code>DW_OP_regN</code> and <code>DW_OP_addr</code>. What is it almost certainly missing, and what symptom would distinguish it from a plain <code>-O2</code> layout surprise?</p>
                <div class="quiz" id="quiz-dwarf-locations-2">
                    <button class="quiz-option" data-correct="true" data-explain="At -O2 the compiler will emit DW_OP_stack_value, which inverts the meaning of the whole expression: the value left on the stack is the variable itself, not the address of the variable. An evaluator that does not implement it treats the register value as a pointer and dereferences it, so the debugger reports a value read from wherever that register happened to point. The symptom is type-correct names and locations with values that look like addresses." onclick="checkQuiz('quiz-dwarf-locations-2', this)">It does not implement <code>DW_OP_stack_value</code>. At <code>-O2</code> the value is often in a register, and that opcode means the stack holds the value itself rather than its address &mdash; so an evaluator without it dereferences the register and prints whatever it pointed at</button>
                    <button class="quiz-option" data-correct="false" data-explain="A missing register opcode would produce an error for the affected variables rather than a plausible value, and would be a decoder failure a user could not miss. The reported symptom is that names, types and locations are all right and only the values are wrong, which points at a misinterpretation of a valid expression rather than a missing instruction." onclick="checkQuiz('quiz-dwarf-locations-2', this)">It does not implement <code>DW_OP_piece</code>, so multi-register variables spanning two registers are reported incorrectly</button>
                    <button class="quiz-option" data-correct="false" data-explain="The SLEB128 operand decoder is shared, and an unsigned bug would corrupt -O0 builds too, which are almost entirely fbreg with negative operands. Since the reader is correct on -O0, signed decoding is fine; the difference between the two builds is which opcodes appear, not how operands are signed." onclick="checkQuiz('quiz-dwarf-locations-2', this)">It still decodes the SLEB128 operand as unsigned, which is harmless at <code>-O0</code> because the offsets happen to be small but breaks once the optimiser produces larger displacements</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a value that decodes cleanly but is consistently wrong across a whole category of variable usually means a missing semantic, not a missing instruction. Check what the expression <em>means</em> before you check whether you can parse it.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The frame base is the CFA, and the CFA is defined by <code>DW_CFA_def_cfa</code> in the unwind section. That is the next concept, and the two are genuinely one mechanism split across two files: <code>DW_AT_frame_base</code> says <em>which rule to apply</em>, and the CFI says <em>what the rule currently is</em>. A location expression that says <code>fbreg -36</code> is unusable without consulting the CFI, because the same expression means different addresses at different points in the function.</p>
                <p>DWARF's little stack machine is the same shape as the bytecodes you met in <a href="/courses/elf/lessons/program-header-table">ELF's note sections</a> and in the <a href="/courses/pe/lessons/pe-base-relocations">PE base relocation</a> concept &mdash; a compact, position-independent instruction sequence evaluated by whoever needs the answer. The COFF course's <a href="/courses/coff/lessons/coff-relocations">REL32 relocation</a> is the same instinct at the machine-code level: store the displacement, not the address, so the value survives being moved.</p>
                <p>One concept remains before the module closes: the unwind information itself, and the other way DWARF solves the "no addresses yet" problem.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-frames">Call Frame Information</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-scopes">Previous: Scopes and Inlining</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-frames">Next: Call Frame Information</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
