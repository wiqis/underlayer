// DWARF Course — Module 2: The Line Number Program
// Concept: The .debug_line header — all fixed fields, decoded from real bytes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_line_header() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The .debug_line Header — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>The <code>.debug_line</code> Header</h1>
            <div class="lesson-meta">20 min &middot; Module 2: The Line Number Program &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything a debugger shows you about "which line am I on" comes from one section. Its first 0x38 bytes are a fixed, self-describing header that tells you how long the header is, how wide an address is, and three constants that the rest of the section is meaningless without.</p>
                <p>Read this header wrongly and the program that follows decodes into confident garbage. Read it correctly and every subsequent byte is interpretable. It is the highest-value 56 bytes in the file.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of the header as answering four questions in order, for a reader that has just been handed an unknown byte stream:</p>
                <ol>
                    <li><strong>How long am I?</strong> <code>unit_length</code> and <code>header_length</code> &mdash; so you know where the variable-length part ends and where the program starts.</li>
                    <li><strong>How wide is the world?</strong> <code>address_size</code> and <code>version</code> &mdash; so you know how many bytes an address occupies and which rules to apply.</li>
                    <li><strong>What are the machine's constants?</strong> <code>minimum_instruction_length</code>, <code>maximum_operations_per_instruction</code>, <code>line_base</code>, <code>line_range</code>.</li>
                    <li><strong>Which byte codes mean what?</strong> <code>opcode_base</code> plus the <code>standard_opcode_lengths</code> table &mdash; so you can skip over an unknown opcode's arguments.</li>
                </ol>
                <p>Questions 3 and 4 exist for one reason: <strong>the format is forward-compatible by construction.</strong> A v5 reader must be able to walk past an opcode it has never heard of. The <code>standard_opcode_lengths</code> table is what makes that possible &mdash; it tells you how many LEB128 arguments to consume so you can skip the opcode and carry on.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The complete header of <code>shape_v5</code>'s <code>.debug_line</code> &mdash; 0x73 bytes total, 0x38 of which is this header. This is the whole section, and the header is the first fourteen lines of it:</p>
                <div class="hex-dump">
                    <pre>00000000: 6f00 0000 0500 0800 3800 0000 0101 01fb  o.......8.......
00000010: 0e0d 0001 0101 0100 0000 0100 0001 0101  ................
00000020: 1f02 0000 0000 2500 0000 0201 1f02 0f04  ......%.........
00000030: 1d00 0000 001d 0000 0000 4800 0000 0150  ..........H..P
00000040: 0000 0001 0523 0009 0229 1100 0000 0000  .....#...)......</pre>
                </div>
                <p>Field by field. Every value below was decoded from these bytes and then required to match <code>readelf --debug-dump=rawline</code> &mdash; agreement, not eyeballing:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">Bytes</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x00</td><td>4</td><td><code>unit_length</code></td><td><code>6f 00 00 00</code></td><td>111 &mdash; bytes after this field, so the unit ends at 0x73</td></tr>
                        <tr><td>0x04</td><td>2</td><td><code>version</code></td><td><code>05 00</code></td><td>5</td></tr>
                        <tr><td>0x06</td><td>1</td><td><code>address_size</code></td><td><code>08</code></td><td>8 bytes</td></tr>
                        <tr><td>0x07</td><td>1</td><td><code>segment_selector_size</code></td><td><code>00</code></td><td>0 &mdash; no segment selector (flat model)</td></tr>
                        <tr><td>0x08</td><td>4</td><td><code>header_length</code></td><td><code>38 00 00 00</code></td><td>56</td></tr>
                        <tr><td>0x0c</td><td>1</td><td><code>minimum_instruction_length</code></td><td><code>01</code></td><td>1 byte</td></tr>
                        <tr><td>0x0d</td><td>1</td><td><code>maximum_operations_per_instruction</code></td><td><code>01</code></td><td>1</td></tr>
                        <tr><td>0x0e</td><td>1</td><td><code>default_is_stmt</code></td><td><code>01</code></td><td>1 &mdash; rows start flagged as statements</td></tr>
                        <tr><td>0x0f</td><td>1</td><td><code>line_base</code></td><td><code>fb</code></td><td><strong>-5</strong> (signed; 0xfb = 251 = -5)</td></tr>
                        <tr><td>0x10</td><td>1</td><td><code>line_range</code></td><td><code>0e</code></td><td>14</td></tr>
                        <tr><td>0x11</td><td>1</td><td><code>opcode_base</code></td><td><code>0d</code></td><td>13 &mdash; opcodes 1-12 are standard</td></tr>
                        <tr><td>0x12</td><td>12</td><td><code>standard_opcode_lengths</code></td><td><code>00 01 01 01 01 00 00 00 01 00 00 01</code></td><td>argument count for opcodes 1-12</td></tr>
                    </tbody>
                </table>
                <p>Three of these deserve more than a table row.</p>
                <p><strong><code>line_base</code> is negative and stored as one byte.</strong> 0xfb is not 251 in this field; it is read as a signed byte, giving -5. This is the offset that lets a single opcode advance the line register <em>backwards</em> as well as forwards, which is how a <code>for</code> loop's closing brace gets attributed to the line after the loop body. Getting the sign wrong turns every line delta into a large positive jump.</p>
                <p><strong><code>header_length</code> is what makes the rest of the header skippable.</strong> It is 56, and the fixed part before it ends at 0x0c. So 0x0c + 0x38 = <strong>0x44</strong> is where the line program begins. The counted directory and file tables sit inside those 56 bytes, because their length depends on the program; the fixed fields do not move.</p>
                <p><strong><code>standard_opcode_lengths</code> is the forward-compatibility table.</strong> Twelve bytes for twelve standard opcodes, summing to 6 arguments in total. Read them as "opcode 1 takes 0 arguments, opcode 2 takes 1, opcode 3 takes 1&hellip;". This is the array a parser consults to skip a byte code it does not recognise: read <code>opcode_base</code>-ish bounds, then consume that many LEB128 values. Without it, an unknown opcode would desynchronise the reader permanently.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Let us walk the whole header by hand, because "the header ends at 0x44" is a claim you should be able to defend.</p>
                <ol>
                    <li><code>6f 00 00 00</code> &rarr; <code>unit_length</code> = 111. Add the 4 bytes of the field itself and the unit occupies 115 bytes = 0x73. The section is 0x73 bytes, so there is exactly one unit and no trailing data.</li>
                    <li><code>05 00</code> &rarr; version 5, so read <code>address_size</code> and <code>segment_selector_size</code> next.</li>
                    <li><code>08 00</code> &rarr; address size 8, segment selector size 0.</li>
                    <li><code>38 00 00 00</code> &rarr; <code>header_length</code> = 56. Position is now 0x0c, so the program starts at <strong>0x44</strong>.</li>
                    <li><code>01 01 01</code> &rarr; min instruction length 1, max ops per instruction 1, default <code>is_stmt</code> 1.</li>
                    <li><code>fb 0e 0d</code> &rarr; <code>line_base</code> = -5, <code>line_range</code> = 14, <code>opcode_base</code> = 13.</li>
                    <li><code>00 01 01 01 01 00 00 00 01 00 00 01</code> &rarr; twelve argument counts. Position is now 0x1e.</li>
                    <li>From 0x1e the header's 56 bytes run out at 0x44 &mdash; the remaining <code>1f 02 00 00 00 00 25 00 00 00 02 01 1f 02 0f 04 1d 00 00 00 ...</code> are the directory and file tables, which the next concept decodes.</li>
                </ol>
                <p>Now the confirmation that matters. <code>readelf</code> prints its first line-program statement at <code>[0x00000044]</code>:</p>
                <pre><code> Line Number Statements:
  [0x00000044]  Set column to 35
  [0x00000046]  Extended opcode 2: set Address to 0x1129
  [0x00000051]  Special opcode 12: advance Address by 0 to 0x1129 and Line by 7 to 8</code></pre>
                <p>Byte 0x44 in our dump is <code>05</code>, which is <code>DW_LNS_set_column</code> &mdash; opcode 5, and the statement is "set column to 35" because the next byte <code>23</code> is 0x23 = 35. The computed program start and readelf's first statement are the same byte. The header is not approximately right; it is exactly right.</p>
                <p>One more check worth doing, because it validates <code>unit_length</code> independently: 0x44 (program start) plus the program itself lands on 0x73, the end of the section. The header claimed 56 bytes, the arithmetic consumed 56 bytes, and the program consumed the rest exactly.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -gdwarf-5 -O0 -o shape_v5 shape.c
$ readelf --debug-dump=rawline shape_v5

$ objcopy --dump-section .debug_line=dl.bin shape_v5
$ xxd -l 80 dl.bin</code></pre>
                <p>Confirm each field yourself against the dump. The ones worth hand-checking are:</p>
                <ul>
                    <li>Bytes 0x04-0x05 read <code>05 00</code> &rarr; 5.</li>
                    <li>Byte 0x06 is <code>08</code>, which should equal <code>readelf</code>'s "Address size (bytes): 8".</li>
                    <li>Byte 0x0f is <code>fb</code>. Write down that this is -5, not 251, and check it against readelf's "Line Base: -5".</li>
                    <li>Bytes 0x08-0x0b give 0x38, and 0x0c + 0x38 must equal the offset of readelf's first statement.</li>
                </ul>
                <p>Then break it deliberately and watch the check you should have written fire. Overwrite <code>unit_length</code> with something absurd:</p>
                <pre><code>$ readelf --debug-dump=rawline broken1
readelf: Warning: The length field (0xfff0) in the debug_line header is wrong - the section is too small</code></pre>
                <p>Note that readelf decoded <em>nothing</em>. A length that overruns the section is not something to clamp or guess at &mdash; it means the unit cannot be trusted, and the correct response is to stop.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a reader has validated the version and consumed the fixed part of the header, so it is positioned at offset 0x0c. It reads <code>header_length = 0x38</code>. At which offset does the line program begin, and which two independent facts confirm the answer?</p>
                <div class="quiz" id="quiz-dwarf-line-header-1">
                    <button class="quiz-option" data-correct="true" data-explain="The reader is at 0x0c and must skip header_length bytes, so the program starts at 0x0c + 0x38 = 0x44. Two independent confirmations: readelf's first Line Number Statement is logged at [0x00000044], and byte 0x44 is 0x05 = DW_LNS_set_column which matches the 0x23 = 35 column readelf reports. The third check is that 0x44 plus the program length lands exactly on 0x73, the section size." onclick="checkQuiz('quiz-dwarf-line-header-1', this)">At 0x0c + 0x38 = <strong>0x44</strong> &mdash; confirmed by readelf logging its first statement at 0x44, and by byte 0x44 being <code>05</code> (set_column) with the next byte <code>23</code> = 35 matching the column readelf prints</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x0c is where the fixed part ends, not where the program begins. The 56 variable-length bytes of directory and file tables sit between them, which is exactly what header_length exists to let you skip." onclick="checkQuiz('quiz-dwarf-line-header-1', this)">At <strong>0x0c</strong>, because header_length describes the fixed fields that end there</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x38 is the length of the variable part, not an absolute offset. It has to be added to the position where the reader currently stands, which is 0x0c after the fixed fields." onclick="checkQuiz('quiz-dwarf-line-header-1', this)">At <strong>0x38</strong>, because header_length is measured from the start of the unit</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Byte 0x0f of a v5 line header is <code>fb</code>. A reader that treats it as an unsigned byte gets <code>line_base = 251</code>. Using the special-opcode rule from the next concepts, what does that do to the very first special opcode in <code>shape_v5</code>, whose raw byte is <code>0x19</code>?</p>
                <div class="quiz" id="quiz-dwarf-line-header-2">
                    <button class="quiz-option" data-correct="true" data-explain="0x19 = 25, so adjusted = 25 - 13 = 12, and 12 % 14 = 12 either way &mdash; the modulo is unaffected. But the line delta is line_base + 12, so -5 + 12 = 7 (correct) becomes 251 + 12 = 263 (wrong). The first row would jump from line 1 to line 264, and every subsequent line would be 256 too high, because 251 and -5 differ by exactly 256." onclick="checkQuiz('quiz-dwarf-line-header-2', this)">The line advance becomes <code>251 + 12 = 263</code> instead of <code>-5 + 12 = 7</code>, so the first row lands on line 264 instead of line 8 &mdash; and every later row is exactly 256 lines too high, because 251 and -5 differ by 256</button>
                    <button class="quiz-option" data-correct="false" data-explain="The modulo part is unaffected: adjusted = 12, and 12 % 14 = 12 whether line_base is -5 or 251. Only the additive line_base term changes, so the error is a constant offset, not a corrupted step size." onclick="checkQuiz('quiz-dwarf-line-header-2', this)">The address advance becomes wrong, because <code>operation_advance = adjusted / line_range</code> also depends on line_base</button>
                    <button class="quiz-option" data-correct="false" data-explain="This confuses line_range with line_base. line_range is 0x0e = 14 and is read unsigned; it is not affected. line_base is the only signed field in the header, and 0xfb is the only byte that is negative." onclick="checkQuiz('quiz-dwarf-line-header-2', this)">The <code>line_range</code> becomes 251 instead of 14, so every opcode's modulo wraps differently</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: in a binary format, exactly one field is signed. Find it, know its width, and never read it unsigned. Here it is one byte, so the failure is a clean 256-line offset rather than chaos &mdash; which makes it easy to spot once you know to look.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p><code>unit_length</code> is the same variable-length prefix that opens every section in the <a href="/courses/pe/lessons/pe-coff-basics">PE COFF header</a> and every ELF section you have parsed, and the discipline of validating it against the section size is the same one from <a href="/courses/dwarf/lessons/dwarf-versions">DWARF 2, 3, 4 and 5</a>. <code>address_size = 8</code> is the DWARF copy of the ELF header's <code>EI_CLASS</code> idea: the same data, a different width, chosen once at the top and obeyed everywhere.</p>
                <p>The header is done. The 56 bytes it skipped over are the next thing worth understanding, because they are the one place where DWARF 5 changed the encoding rather than just adding a field.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-file-tables">Directory and File Tables</a> &mdash; how a line number becomes a filename, in two incompatible encodings.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-versions">Previous: DWARF 2, 3, 4 and 5</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-file-tables">Next: Directory and File Tables</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
