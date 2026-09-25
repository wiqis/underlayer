// DWARF Course — Module 2: The Line Number Program
// Concept: From rows to source lines — sequences, lookup, and the high_pc trap.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_address_to_line() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("From Rows to Source Lines — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>From Rows to Source Lines</h1>
            <div class="lesson-meta">18 min &middot; Module 2: The Line Number Program &middot; Behaviour</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You can now decode a line program. The remaining question is the one a debugger asks every time you stop: <em>"I am at address 0x1154 &mdash; what do I tell the user?"</em></p>
                <p>Answering it wrong is not a small error. A lookup that ignores where one function's rows end and the next one's begin will happily report that address 0x2000 is "line 17 of shape.c", because line 17 was the last row it happened to decode. Every line-number feature you have ever used in a debugger depends on two rules getting this right.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two rules, and together they are the whole lookup:</p>
                <ol>
                    <li><strong>A row describes a range, not a point.</strong> The row at address A applies to every byte from A up to the next row's address. A row is a "starting here" marker, not a "this is here" marker.</li>
                    <li><strong>Rows are grouped into sequences, and sequences are contiguous.</strong> Within one sequence, addresses increase strictly. A new sequence is opened by <code>DW_LNE_set_address</code> and closed by <code>DW_LNE_end_sequence</code>. A lookup must not cross a sequence boundary, because the address ranges on either side may be in completely different places in memory.</li>
                </ol>
                <p>That is the model. Everything else is bookkeeping.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Our program has <strong>exactly one sequence</strong>, and it is the complete opcode list from <code>shape_v5</code> &mdash; 22 statements, start to end:</p>
                <pre><code>  [0x00000044]  Set column to 35
  [0x00000046]  Extended opcode 2: set Address to 0x1129
  [0x00000051]  Special opcode 12: advance Address by 0 to 0x1129 and Line by 7 to 8
  [0x00000052]  Set column to 14
  [0x00000054]  Special opcode 202: advance Address by 14 to 0x1137 and Line by 1 to 9
  [0x00000055]  Set column to 1
  [0x00000057]  Special opcode 118: advance Address by 8 to 0x113f and Line by 1 to 10
  [0x00000058]  Set column to 16
  [0x0000005a]  Special opcode 35: advance Address by 2 to 0x1141 and Line by 2 to 12
  [0x0000005b]  Set column to 9
  [0x0000005d]  Special opcode 175: advance Address by 12 to 0x114d and Line by 2 to 14
  [0x0000005e]  Set column to 11
  [0x00000060]  Special opcode 104: advance Address by 7 to 0x1154 and Line by 1 to 15
  [0x00000061]  Set column to 9
  [0x00000063]  Extended opcode 4: set Discriminator to 1
  [0x00000067]  Special opcode 215: advance Address by 15 to 0x1163 and Line by 0 to 15
  [0x00000068]  Set column to 13
  [0x0000006a]  Special opcode 48: advance Address by 3 to 0x1166 and Line by 1 to 16
  [0x0000006b]  Set column to 1
  [0x0000006d]  Special opcode 48: advance Address by 3 to 0x1169 and Line by 1 to 17
  [0x0000006e]  Advance PC by 2 to 0x116b
  [0x00000070]  Extended opcode 1: End of Sequence</code></pre>
                <p>Structure it and the shape is obvious:</p>
                <ul>
                    <li><code>set_column</code> statements carry no row. They only change what the <em>next</em> emitted row will say about the column.</li>
                    <li><code>set_address</code> at 0x46 opens the sequence at 0x1129. It emits no row by itself.</li>
                    <li>Each <code>Special opcode</code> emits one row. Nine of them, so nine rows.</li>
                    <li><code>Advance PC by 2 to 0x116b</code> is <code>DW_LNS_advance_pc</code>, which moves the address but emits nothing. The range from 0x1169 up to 0x116b is therefore still attributed to the <strong>line 17</strong> row &mdash; the final <code>&#125;</code> covers the last two bytes of <code>main</code> as well as the instructions readelf listed before it.</li>
                    <li><code>End of Sequence</code> at 0x70 closes it at 0x116b. The sequence's end address is <em>exclusive</em>: the last row runs from 0x1169 to 0x116b.</li>
                </ul>
                <p>So the sequence covers <strong>0x1129 to 0x116b</strong>, which is 0x42 = 66 bytes. Hold onto that number, because the next unit uses it to catch a very common bug.</p>
                <h3>The lookup, stated precisely</h3>
                <p>To map an address A to a source line:</p>
                <ol>
                    <li>Find the sequence whose [start, end) range contains A. If none does, there is no line information for A &mdash; say so rather than guessing.</li>
                    <li>Within that sequence, find the last row whose address is <code>&le; A</code>. That is the row. Its <code>file</code> and <code>line</code> are the answer.</li>
                </ol>
                <p>Step 2's "<em>last</em> row" and step 1's "must not cross a boundary" are the two rules. Get step 2 wrong by taking the <em>first</em> row at or below A, or by stopping at the row whose address exactly equals A, and you will report the wrong line for most addresses. Get step 1 wrong and you will report lines from an unrelated function.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Run the lookup on real addresses from the disassembly we started with:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Address</th><th scope="col">Instruction</th><th scope="col">Last row &le; A</th><th scope="col">Answer</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x1129</td><td><code>endbr64</code></td><td>row at 0x1129</td><td>shape.c<strong>8</strong></td></tr>
                        <tr><td>0x1131</td><td><code>mov %edi,-0x4(%rbp)</code></td><td>row at 0x1129</td><td>shape.c<strong>8</strong></td></tr>
                        <tr><td>0x1137</td><td><code>mov -0x4(%rbp),%edx</code></td><td>row at 0x1137</td><td>shape.c<strong>9</strong></td></tr>
                        <tr><td>0x113d</td><td><code>add %edx,%eax</code></td><td>row at 0x1137</td><td>shape.c<strong>9</strong></td></tr>
                        <tr><td>0x113e</td><td><code>(second byte of that same 2-byte add)</code></td><td>row at 0x1137</td><td>shape.c<strong>9</strong> &mdash; mid-instruction</td></tr>
                        <tr><td>0x113f</td><td><code>pop %rbp</code></td><td>row at 0x113f</td><td>shape.c<strong>10</strong></td></tr>
                        <tr><td>0x1154</td><td><code>p.y = add(p.x,4)</code></td><td>row at 0x1154</td><td>shape.c<strong>15</strong></td></tr>
                        <tr><td>0x1163</td><td><code>(second run of line 15)</code></td><td>row at 0x1163</td><td>shape.c<strong>15</strong>, discriminator 1</td></tr>
                        <tr><td>0x116a</td><td><code>(last bytes of main)</code></td><td>row at 0x1169</td><td>shape.c<strong>17</strong></td></tr>
                        <tr><td>0x2000</td><td><code>(outside the sequence)</code></td><td>none</td><td><strong>no line information</strong></td></tr>
                    </tbody>
                </table>
                <p>Three rows in that table earn their keep. <strong>0x113e</strong> is in the middle of the <code>add</code> instruction at 0x113d, and it still resolves to line 9 &mdash; because rows describe ranges, not instructions. <strong>0x116a</strong> is covered by the line 17 row even though no opcode started a row there, because <code>advance_pc</code> moved the address without emitting anything. And <strong>0x2000</strong> is the one that matters: the honest answer is "no line information", and a debugger that answers "line 17" here is producing a confident lie that will send a developer to the wrong file.</p>
                <p>And now the trap. The compilation unit in <code>.debug_info</code> declares this function's extent, and here is the relevant pair of attributes, decoded from the real bytes in <a href="/courses/dwarf/lessons/dwarf-line-header">the header concept</a>'s dump:</p>
                <pre><code>  DW_AT_low_pc  : 0x1129
  DW_AT_high_pc : 0x42</code></pre>
                <p><code>0x1129 + 0x42 = 0x116b</code> &mdash; which is exactly the end of the sequence. The extent and the line program agree, from two completely different sections.</p>
                <p>But look at what <code>DW_AT_high_pc</code> <em>is</em>: the value <code>0x42</code> is a <strong>length</strong>, not an address, because this DIE uses <code>DW_FORM_data8</code>. A reader that assumes <code>high_pc</code> is an address concludes the code ends at address <code>0x42</code> &mdash; 4,171 bytes into address zero, nowhere near the binary. The DWARF specification allows either an address or a length here, and <strong>the form tells you which</strong>. This single ambiguity is the most common real bug in DWARF tooling, and it is why you must read the form, not just the value.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <p>Check the two halves of the extent against each other:</p>
                <pre><code>$ readelf --debug-dump=rawline shape_v5 | sed -n '/Line Number Statements/,$p' | tail -3
$ readelf --debug-dump=info shape_v5 | sed -n '/DW_AT_low_pc/,/DW_AT_stmt_list/p'</code></pre>
                <p>What to look for: the line program's last address is 0x116b, and <code>low_pc + high_pc</code> is also 0x116b. Two sections, one fact, independently encoded.</p>
                <p>Then confirm the form determines the meaning, by looking at the raw DIE bytes for those two attributes:</p>
                <pre><code>$ objcopy --dump-section .debug_info=di.bin shape_v5
$ xxd -s 0x1f -l 16 di.bin</code></pre>
                <p>You will see <code>29 11 00 00 00 00 00 00</code> (8 bytes &mdash; <code>DW_FORM_addr</code>) followed by <code>42 00 00 00 00 00 00 00</code> (8 bytes &mdash; <code>DW_FORM_data8</code>). Same width, completely different meaning. The form byte in the abbrev table is the only thing that tells them apart.</p>
                <p>Finally, see what a debugger does with a stripped file, which is the honest "no line information" case:</p>
                <pre><code>$ cp shape_v5 s &amp;&amp; strip s
$ objdump -dl s | head -5</code></pre>
                <p>No line annotations at all. That is not a bug &mdash; it is the correct output for a file with no line table, and the exact situation the first concept started from.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a line program's rows say address 0x1129 is line 8, and 0x1137 is line 9. A lookup is asked for address 0x1134. Which row applies, and why is that not surprising?</p>
                <div class="quiz" id="quiz-dwarf-address-to-line-1">
                    <button class="quiz-option" data-correct="true" data-explain="0x1134 falls between 0x1129 and 0x1137, so the last row at or below it is the 0x1129 row, giving line 8. That is not surprising because a row is a range starting at its address, not a point - it applies until the next row begins. This is exactly why 0x113d, the add instruction, correctly reports line 9 via the 0x1137 row." onclick="checkQuiz('quiz-dwarf-address-to-line-1', this)">The row at 0x1129, giving line 8 &mdash; because a row covers every byte from its address up to the next row's, so 0x1134 falls inside the line 8 range</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the natural first guess, and it is wrong. There is no row at 0x1134; rows exist only at 0x1129, 0x1137, 0x113f and so on. The lookup finds the last row at or below the address, not a row at the address itself." onclick="checkQuiz('quiz-dwarf-address-to-line-1', this)">No row applies, so 0x1134 has no line information because it is not a row boundary</button>
                    <button class="quiz-option" data-correct="false" data-explain="This confuses the line table with the symbol table. The nearest named symbol is add at 0x1129, but symbols name addresses and do not carry line numbers - that is the entire job of the line program, and it is why the two are separate mechanisms." onclick="checkQuiz('quiz-dwarf-address-to-line-1', this)">The row at 0x1137, giving line 9, because the lookup rounds up to the next row</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A linker has concatenated four object files into one executable, each contributing its own line program unit. Their code lands at 0x1000, 0x2000, 0x18000 and 0x40000. A lookup for 0x18500 returns "line 41 of a.c". What did the tool do, and which of the two rules from this concept did it break?</p>
                <div class="quiz" id="quiz-dwarf-address-to-line-2">
                    <button class="quiz-option" data-correct="true" data-explain="0x18500 falls inside unit 3's range but not inside its last row - and a naive single-table lookup takes the last row at or below the address across the whole concatenated list, which belongs to unit 2. The fix is to locate the sequence containing A first and search only within it. The tell-tale symptom is a plausible filename from a different translation unit, which is why this bug is so hard to catch." onclick="checkQuiz('quiz-dwarf-address-to-line-2', this)">It searched across sequence boundaries and picked the last row at or below 0x18500 in the <em>concatenated</em> list &mdash; which belongs to the unit at 0x1000. It broke rule 2: never cross a sequence boundary. Find the sequence containing the address, then search only within it</button>
                    <button class="quiz-option" data-correct="false" data-explain="Taking the first row at or below the address would report an earlier line than the correct one, and the answer here names a.c, whose unit is elsewhere entirely. The real failure is that the search was not confined to the sequence that actually contains 0x18500." onclick="checkQuiz('quiz-dwarf-address-to-line-2', this)">It used the wrong row within the right sequence, because it took the first row at or below the address instead of the last &mdash; it broke rule 1</button>
                    <button class="quiz-option" data-correct="false" data-explain="Rule 1 is about ranges within a sequence, and a correct range-based lookup would find the unit at 0x18000 immediately. The reported file belongs to a different unit, so the tool never confined its search to that unit - this is a sequence-boundary failure, not an ordering one." onclick="checkQuiz('quiz-dwarf-address-to-line-2', this)">It stopped at the wrong sequence boundary, because it treated the end of one unit's rows as the start of the next &mdash; it broke rule 1 instead of rule 2</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a lookup returns a confident answer from the wrong file, suspect the container, not the content. The data inside a table is usually right; the mistake is almost always about which rows you allowed yourself to consider.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Sequence ranges are <a href="/courses/elf/lessons/program-header-table">ELF program header segments</a> in miniature: a start address, an end address, and a rule that you must find the containing range before looking up anything inside it. The <code>DW_AT_low_pc</code>/<code>DW_AT_high_pc</code> pair is the same shape as a segment's <code>p_vaddr</code> and <code>p_vaddr + p_filesz</code>, and suffers from the same address-versus-length ambiguity that <a href="/courses/pe/lessons/pe-rva-conversion">PE RVA conversion</a> has to handle.</p>
                <p>You have now taken a binary from "here is a program" to "here is exactly which source line each address belongs to", entirely from bytes on disk. That closes Module 2, and it is the whole of the line-number half of DWARF.</p>
                <p>What remains is the other half: <code>.debug_info</code> and <code>.debug_abbrev</code>, which describe <em>types and variables</em> rather than lines. That is where a debugger gets <code>int32_t</code> instead of "4 bytes of something", and it is where the abbreviation table's indirection &mdash; the one piece of DWARF that is genuinely hard to hold in your head &mdash; finally earns its keep.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-special-opcodes">Previous: The Special Opcodes</a></span>
                <span><a href="/courses/dwarf">Course home</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
