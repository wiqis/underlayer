// DWARF Course — Module 2: The Line Number Program
// Concept: Special opcodes — the arithmetic, verified against every statement.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_special_opcodes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Special Opcodes — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>The Special Opcodes</h1>
            <div class="lesson-meta">20 min &middot; Module 2: The Line Number Program &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Twenty-one of the statements in <code>shape_v5</code>'s line program are single bytes. Each one carries a line delta <em>and</em> an address delta <em>and</em> emits a row, with no operands at all. That is the entire reason 115 bytes can describe every source line in a program.</p>
                <p>The trick is a mixed-radix division. It is also the single most commonly implemented-wrong piece of DWARF, because the spec's five steps are ordered in a way that trips people up, and because the result looks self-consistent even when it is wrong.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>There is a whole family of plausible questions you could ask of one byte: how far forward, which line, which column, is this a statement, and end of function. Instead of five opcodes, DWARF picks the <em>common</em> case &mdash; "advance the address and the line, emit a row" &mdash; and packs three answers into one byte. Anything unusual falls back to the standard opcodes.</p>
                <p>The packing works like a clock face that also counts steps. The byte, minus <code>opcode_base</code>, is one number. Division by <code>line_range</code> peels off the coarse part (how many instructions to skip); the remainder peels off the fine part (how many lines to move). One number, two answers, no operands.</p>
                <div class="callout callout-warn">
                    <strong>The signed field is the trap.</strong> <code>line_base</code> is <strong>-5</strong> in our file, and a special opcode with a small adjusted value computes a <em>negative</em> line delta. That is not a bug: it is how the compiler attributes a loop's closing brace to the line after the loop. Read the byte as unsigned and every line in the program goes wildly wrong &mdash; and, as we computed in <a href="/courses/dwarf/lessons/dwarf-line-header">the header concept</a>, wrong by a suspiciously tidy 256.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The specification defines exactly five steps, in this order. The order is load-bearing:</p>
                <div class="formula">
1. operation_advance = adjusted_opcode / line_range<br>
2. address_advance = min_inst_len &times; ((op_index + operation_advance) / max_ops_per_inst)<br>
3. op_index = (op_index + operation_advance) % max_ops_per_inst<br>
4. address += address_advance<br>
5. line += line_base + (adjusted_opcode % line_range)
                </div>
                <p>where <code>adjusted_opcode = opcode_byte - opcode_base</code>, division is integer division, and step 5 also <strong>emits a row</strong> with the current <code>address</code>, <code>op_index</code>, <code>file</code>, <code>line</code>, <code>column</code> and <code>is_stmt</code>.</p>
                <p>Two details in that listing cause most of the bugs:</p>
                <ul>
                    <li><strong>Step 2 uses the <em>old</em> <code>op_index</code>.</strong> It is not recomputed first. If you update <code>op_index</code> before computing <code>address_advance</code>, you get a different answer on any machine where <code>max_ops_per_inst &gt; 1</code>.</li>
                    <li><strong>Step 3 takes a modulus.</strong> So <code>op_index</code> wraps. With <code>max_ops_per_inst = 1</code> &mdash; our case &mdash; it is <em>always</em> zero after any special opcode, and step 2 collapses to <code>address_advance = min_inst_len &times; operation_advance</code>. That simplification is why this bug so often hides on x86.</li>
                </ul>
                <p>Our file's three constants, from the header: <code>opcode_base = 13</code>, <code>line_base = -5</code>, <code>line_range = 14</code>, <code>min_inst_len = 1</code>, <code>max_ops_per_inst = 1</code>.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Every special opcode in <code>shape_v5</code>, decoded from the raw bytes. Note that <strong>readelf prints the <em>adjusted</em> opcode, not the raw byte</strong> &mdash; its "Special opcode 12" is the raw byte <code>0x19</code> = 25 minus 13. Knowing that saves an hour of confusion the first time.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Raw</th><th scope="col">adjusted</th><th scope="col">op_adv = adj/14</th><th scope="col">line_inc = -5 + (adj%14)</th><th scope="col">address &rarr;</th><th scope="col">line &rarr;</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x51</td><td><code>0x19</code> = 25</td><td>12</td><td>0</td><td>-5 + 12 = <strong>7</strong></td><td>0x1129</td><td>1 &rarr; <strong>8</strong></td></tr>
                        <tr><td>0x54</td><td><code>0xd7</code> = 215</td><td>202</td><td>14</td><td>-5 + 6 = <strong>1</strong></td><td>&rarr; 0x1137</td><td>8 &rarr; <strong>9</strong></td></tr>
                        <tr><td>0x57</td><td><code>0x83</code> = 131</td><td>118</td><td>8</td><td>-5 + 6 = <strong>1</strong></td><td>&rarr; 0x113f</td><td>9 &rarr; <strong>10</strong></td></tr>
                        <tr><td>0x5a</td><td><code>0x30</code> = 48</td><td>35</td><td>2</td><td>-5 + 7 = <strong>2</strong></td><td>&rarr; 0x1141</td><td>10 &rarr; <strong>12</strong></td></tr>
                        <tr><td>0x5d</td><td><code>0xbc</code> = 188</td><td>175</td><td>12</td><td>-5 + 7 = <strong>2</strong></td><td>&rarr; 0x114d</td><td>12 &rarr; <strong>14</strong></td></tr>
                        <tr><td>0x60</td><td><code>0x75</code> = 117</td><td>104</td><td>7</td><td>-5 + 6 = <strong>1</strong></td><td>&rarr; 0x1154</td><td>14 &rarr; <strong>15</strong></td></tr>
                        <tr><td>0x67</td><td><code>0xe4</code> = 228</td><td>215</td><td>15</td><td>-5 + 5 = <strong>0</strong></td><td>&rarr; 0x1163</td><td>15 &rarr; <strong>15</strong></td></tr>
                        <tr><td>0x6a</td><td><code>0x3d</code> = 61</td><td>48</td><td>3</td><td>-5 + 6 = <strong>1</strong></td><td>&rarr; 0x1166</td><td>15 &rarr; <strong>16</strong></td></tr>
                        <tr><td>0x6d</td><td><code>0x3d</code> = 61</td><td>48</td><td>3</td><td>-5 + 6 = <strong>1</strong></td><td>&rarr; 0x1169</td><td>16 &rarr; <strong>17</strong></td></tr>
                    </tbody>
                </table>
                <p>Read the table's address column down and it is the disassembly, exactly. And read the line column down and it is the source file, exactly:</p>
                <pre><code>0x1129  line 8    int32_t add(int32_t a, int32_t b) &#123;     &lt;-- add() prologue
0x1137  line 9        return a + b;                   &lt;-- the add instruction
0x113f  line 10   &#125;                                  &lt;-- pop, ret
0x1141  line 12   int main(void) &#123;
0x114d  line 14       p.x = 3;
0x1154  line 15       p.y = add(p.x, 4);
0x1163  line 15       p.y = add(p.x, 4);                &lt;-- same line, new address
0x1166  line 16       return p.y;
0x1169  line 17   &#125;</code></pre>
                <p>Three things in that table are worth pausing on.</p>
                <p><strong>Row 1 produces a line delta of +7 with a byte that looks tiny.</strong> <code>0x19</code> = 25, adjusted 12, and 12 % 14 = 12, giving -5 + 12 = 7. This is the "skip forward to the next statement" case: the compiler is jumping from the top of the function to the first real statement, and it chose to do that with a delta of 7 lines and an address delta of 0.</p>
                <p><strong>Row 6 produces a line delta of exactly 0.</strong> <code>0xe4</code> = 228, adjusted 215, and 215 % 14 = 5, giving -5 + 5 = 0. The line does not change but the address advances 15 bytes, so a <em>new row is still emitted</em> on the same source line. This is the row at 0x1163, and it exists because a single C statement compiled to two separate instruction runs. Without it, a breakpoint set on line 15 would skip half the statement.</p>
                <p><strong>Negative deltas are possible and expected.</strong> Nothing in this table needs one, because <code>shape.c</code> has no loop. A <code>for</code> loop in a <code>-O0</code> build produces a special opcode whose adjusted value is <em>less than 5</em>, producing a negative line increment &mdash; the machine is stepping backwards in your source as it walks forward in the binary. If your reader treats the line delta as unsigned, the first loop it meets produces an enormous positive jump and the rest of the file is nonsense. Try it:</p>
                <pre><code>$ printf 'int s=0;\nfor(int i=0;i&lt;3;i++) s+=i;\nreturn s;\n' &gt; loop.c
$ gcc -gdwarf-5 -O0 -o loop loop.c
$ readelf --debug-dump=rawline loop | sed -n '/Line Number Statements/,$p'</code></pre>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <p>Do the arithmetic by hand first, then check against readelf. Pick the first special opcode:</p>
                <pre><code>$ objcopy --dump-section .debug_line=dl.bin shape_v5
$ xxd -s 0x51 -l 1 dl.bin          # the byte is 0x19
$ readelf --debug-dump=rawline shape_v5 | grep '0x00000051'</code></pre>
                <p>Your working: raw byte 0x19 = 25. <code>adjusted = 25 - 13 = 12</code>. <code>operation_advance = 12 / 14 = 0</code>. <code>address_advance = 1 &times; ((0 + 0) / 1) = 0</code>. <code>line_increment = -5 + (12 % 14) = -5 + 12 = 7</code>. So the address holds at 0x1129 and the line goes 1 &rarr; 8. Readelf prints <em>"advance Address by 0 to 0x1129 and Line by 7 to 8"</em>.</p>
                <p>Now the whole program, and check each row against the table above:</p>
                <pre><code>$ readelf --debug-dump=rawline shape_v5 | sed -n '/Line Number Statements/,$p'</code></pre>
                <p>What to look for: that readelf's "Special opcode N" is always the adjusted value, never the raw byte. If you expect the raw byte you will think readelf is wrong. It is not; you are reading the wrong column.</p>
                <p>Then the negative-line-delta experiment from above, which is the fastest way to make sure your own reader handles a signed line register.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: <code>line_base = -5</code>, <code>line_range = 14</code>. A special opcode's adjusted value is 3. What address delta and what line delta does it produce, and is the line delta legal?</p>
                <div class="quiz" id="quiz-dwarf-special-opcodes-1">
                    <button class="quiz-option" data-correct="true" data-explain="3 / 14 = 0, so the address does not move. 3 % 14 = 3, and -5 + 3 = -2: a negative line delta. This is completely legal and it is how a loop's back edge is encoded - the address goes forward while the line register goes backwards, back to the top of the loop body." onclick="checkQuiz('quiz-dwarf-special-opcodes-1', this)">Address delta 0, line delta <strong>-2</strong> &mdash; and yes, it is legal: it is exactly how a loop's back edge is encoded, with the address moving forward while the line register returns to the top of the loop body</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the unsigned reading of line_base, and it is the bug this concept exists to prevent. A reader that does this reports a jump from line 1 to line 256 on the first back edge, which is a valid line number and therefore passes every sanity check you are likely to write." onclick="checkQuiz('quiz-dwarf-special-opcodes-1', this)">Address delta 0, line delta <strong>+9</strong> &mdash; because the delta is <code>line_base + 3</code> and the unsigned reading of <code>0xfb</code> is 251</button>
                    <button class="quiz-option" data-correct="false" data-explain="The division is by line_range = 14, and 3 / 14 = 0, so the address does not move. address_advance also multiplies by minimum_instruction_length, which is 1 here, so it cannot turn 0 into 3 either." onclick="checkQuiz('quiz-dwarf-special-opcodes-1', this)">Address delta 3, line delta <strong>-2</strong> &mdash; because operation_advance is the adjusted value itself when it is below line_range</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your reader is correct on x86-64, where <code>max_ops_per_instruction = 1</code>, so step 3 always resets <code>op_index</code> to 0 and step 2 simplifies. It is now given a file from a VLIW target with <code>max_ops_per_instruction = 4</code>, <code>min_inst_len = 1</code>, and an <code>op_index</code> of 3 carried in from the previous opcode. A new special opcode has an adjusted value of 12. What does your reader compute, and what is correct?</p>
                <div class="quiz" id="quiz-dwarf-special-opcodes-2">
                    <button class="quiz-option" data-correct="true" data-explain="operation_advance = 12 / 14 = 0. Step 2 must use the OLD op_index of 3: 1 * ((3 + 0) / 4) = 0. Step 3 then sets op_index = (3 + 0) % 4 = 3. A reader that updated op_index first, or that had collapsed step 2 because max_ops was 1 on its home target, computes 1 * ((0 + 0) / 4) = 0 here too - but the two agree only when the sum stays below max_ops, and diverge as soon as op_index + operation_advance reaches 4." onclick="checkQuiz('quiz-dwarf-special-opcodes-2', this)">It computes <code>1 &times; ((3 + 0) / 4) = 0</code> &mdash; which is correct. The trap is that this happens to agree with the x86 simplification, so the bug stays hidden until an <code>op_index + operation_advance</code> that crosses a multiple of 4</button>
                    <button class="quiz-option" data-correct="false" data-explain="This collapses the division by maximum_operations_per_instruction, which is precisely the term that exists to handle variable-length instructions. With max_ops = 4 the division by 4 is required: an instruction can hold several operations and the address only advances when they pass an instruction boundary." onclick="checkQuiz('quiz-dwarf-special-opcodes-2', this)">It computes <code>1 &times; (3 + 0) = 3</code> &mdash; which is correct, because the division by <code>max_ops_per_instruction</code> is only needed when the value is 1</button>
                    <button class="quiz-option" data-correct="false" data-explain="Step 3 is a modulo, so op_index stays within 0..3 and is carried forward. That carry is the entire reason the register exists; discarding it would make op_index permanently 0 and break every VLIW file that spans an instruction boundary." onclick="checkQuiz('quiz-dwarf-special-opcodes-2', this)">It computes <code>1 &times; ((0 + 0) % 4) = 0</code> and resets <code>op_index</code> to 0 &mdash; which is correct, because step 3 overwrites it unconditionally</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a formula contains a term that is provably 1 on your development machine, that term is untested. Deliberately run your parser against a target where it is not 1, or at minimum write a unit test that forces it away from 1.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Mixed-radix packing for compactness is not new to you: it is the same trick as <a href="/courses/elf/lessons/binary-representation">variable-length integers</a> and as the <code>block_align</code> math in <a href="/courses/pe/lessons/pe-alignment">PE section alignment</a>. One number, decomposed by division, encoding several independent fields within the range each can actually take.</p>
                <p>The <code>op_index</code> idea is a genuine lesson about machine code, and it connects to <a href="/courses/elf/lessons/common-sections">the ELF section flags</a> you studied earlier: it exists because instructions are not all the same length, so "how far have we moved within this instruction" is real state a decoder must carry. The same problem is why <a href="/courses/elf/lessons/entry-point">VLIW and out-of-order execution</a> are hard.</p>
                <p>You can now decode every statement in the program. One concept remains: what a debugger actually <em>does</em> with the resulting table, and the two rules that make a row mean anything at all.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-address-to-line">From Rows to Source Lines</a> &mdash; sequences, the lookup a debugger performs, and the <code>high_pc</code> trap.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-standard-opcodes">Previous: The Standard Opcodes</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-address-to-line">Next: From Rows to Source Lines</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
