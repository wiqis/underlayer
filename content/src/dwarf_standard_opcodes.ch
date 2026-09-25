// DWARF Course — Module 2: The Line Number Program
// Concept: The twelve standard opcodes and the state machine they mutate.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_standard_opcodes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Standard Opcodes — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>The Standard Opcodes</h1>
            <div class="lesson-meta">16 min &middot; Module 2: The Line Number Program &middot; Behaviour</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The line program is a tiny state machine. It holds a handful of registers &mdash; where we are, which line, which file &mdash; and a stream of opcodes mutates them. Nothing in it says "this instruction is on line 9"; it says "move forward 6 bytes and add 1 to the line", and the reader is expected to notice that a new row has begun.</p>
                <p>That design is why the format is so compact: 115 bytes describe 21 distinct address-to-line rows. It is also why you cannot skim it. Every opcode you misread shifts the cursor, and every shift produces a plausible-looking wrong address.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Six registers. This is the entire state a line-program reader carries between opcodes:</p>
                <ol>
                    <li><code>address</code> &mdash; where in the binary we are.</li>
                    <li><code>op_index</code> &mdash; which operation within the current instruction.</li>
                    <li><code>file</code> &mdash; which file number.</li>
                    <li><code>line</code> &mdash; which line number.</li>
                    <li><code>column</code> &mdash; which column.</li>
                    <li><code>is_stmt</code> &mdash; is this the start of a statement?</li>
                </ol>
                <p>Opcodes fall into three groups, and the grouping is what makes them learnable:</p>
                <ul>
                    <li><strong>Set</strong> an absolute value (<code>set_file</code>, <code>set_column</code>, <code>set_isa</code>).</li>
                    <li><strong>Advance</strong> a value by a delta (<code>advance_pc</code>, <code>advance_line</code>).</li>
                    <li><strong>Emit a row</strong> and toggle flags (<code>copy</code>, <code>negate_stmt</code>, <code>set_basic_block</code>, <code>const_add_pc</code>, <code>fixed_advance_pc</code>, <code>set_prologue_end</code>, <code>set_epilogue_begin</code>).</li>
                </ul>
                <p>Plus a separate <strong>extended</strong> family, signalled by a leading <code>0x00</code> byte: <code>end_sequence</code>, <code>set_address</code>, <code>define_file</code>, <code>set_discriminator</code>. These carry their own length so a reader can skip them, and they are what actually start and stop a sequence.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Twelve standard opcodes, with the argument counts the header published at 0x12 so you can skip any of them:</p>
                <table>
                    <thead>
                        <tr><th scope="col">#</th><th scope="col">Name</th><th scope="col">Args</th><th scope="col">Effect</th><th scope="col">In <code>shape_v5</code>?</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1</td><td><code>DW_LNS_copy</code></td><td>0</td><td>Emit a row with the current registers, then reset the transient ones</td><td>no</td></tr>
                        <tr><td>2</td><td><code>DW_LNS_advance_pc</code></td><td>1 ULEB</td><td><code>address += arg &times; min_inst_len</code></td><td><strong>yes</strong> &mdash; once, <code>02</code></td></tr>
                        <tr><td>3</td><td><code>DW_LNS_advance_line</code></td><td>1 SLEB</td><td><code>line += arg</code> (signed: may go backwards)</td><td>no</td></tr>
                        <tr><td>4</td><td><code>DW_LNS_set_file</code></td><td>1 ULEB</td><td>Set the file number</td><td>no</td></tr>
                        <tr><td>5</td><td><code>DW_LNS_set_column</code></td><td>1 ULEB</td><td>Set the column</td><td><strong>yes</strong> &mdash; 6 times</td></tr>
                        <tr><td>6</td><td><code>DW_LNS_negate_stmt</code></td><td>0</td><td>Flip <code>is_stmt</code></td><td>no</td></tr>
                        <tr><td>7</td><td><code>DW_LNS_set_basic_block</code></td><td>0</td><td>Mark the start of a basic block</td><td>no</td></tr>
                        <tr><td>8</td><td><code>DW_LNS_const_add_pc</code></td><td>0</td><td>Advance <code>address</code> by the same rule as a special opcode with <code>adjusted_opcode = 255</code></td><td>no</td></tr>
                        <tr><td>9</td><td><code>DW_LNS_fixed_advance_pc</code></td><td>1 u16</td><td><code>address += arg</code> <em>bytes</em>, ignoring min_inst_len</td><td>no</td></tr>
                        <tr><td>10</td><td><code>DW_LNS_set_prologue_end</code></td><td>0</td><td>Mark the end of the function prologue</td><td>no</td></tr>
                        <tr><td>11</td><td><code>DW_LNS_set_epilogue_begin</code></td><td>0</td><td>Mark the start of the epilogue</td><td>no</td></tr>
                        <tr><td>12</td><td><code>DW_LNS_set_isa</code></td><td>1 ULEB</td><td>Set the instruction-set identifier</td><td>no</td></tr>
                    </tbody>
                </table>
                <p>Two rows deserve a warning, because both are places where implementations and the spec's letter have historically parted company.</p>
                <p><strong><code>DW_LNS_copy</code> does not appear once in our program</strong>, and that is not a mistake. In practice GCC emits rows via <em>special</em> opcodes, which implicitly emit a row as part of advancing. <code>copy</code> is the explicit "a row ends here" opcode, and a compiler that wants to break a row without changing the address uses it. A reader must still implement it: a program that used it would break entirely otherwise.</p>
                <p><strong><code>DW_LNS_advance_pc</code> and <code>DW_LNS_fixed_advance_pc</code> are not the same opcode.</strong> The first multiplies its argument by <code>minimum_instruction_length</code>; the second adds its argument as raw bytes. On x86-64, where <code>min_inst_len = 1</code>, they coincide &mdash; which is exactly why the bug survives on the platform most people test on. On a machine where the minimum instruction length is 4, the same byte means two different distances.</p>
                <p>And the extended opcodes, whose leading <code>0x00</code> marks them, followed by a ULEB <em>block length</em>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Sub-opcode</th><th scope="col">Name</th><th scope="col">Payload</th><th scope="col">In <code>shape_v5</code>?</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1</td><td><code>DW_LNE_end_sequence</code></td><td>none</td><td><strong>yes</strong> &mdash; closes the program at 0x70</td></tr>
                        <tr><td>2</td><td><code>DW_LNE_set_address</code></td><td>one address, <code>address_size</code> bytes</td><td><strong>yes</strong> &mdash; sets 0x1129 at 0x46</td></tr>
                        <tr><td>3</td><td><code>DW_LNE_define_file</code></td><td>same shape as a v4 file entry</td><td>no</td></tr>
                        <tr><td>4</td><td><code>DW_LNE_set_discriminator</code></td><td>1 ULEB</td><td><strong>yes</strong> &mdash; sets 1 at 0x63</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here are the two opcodes that actually occur, read straight out of the program bytes. The program begins at 0x44.</p>
                <p><strong><code>DW_LNS_set_column</code> at 0x44</strong> &mdash; the bytes are <code>05 23</code>:</p>
                <ul>
                    <li><code>05</code> &rarr; opcode 5, which the table says is <code>set_column</code> with 1 argument.</li>
                    <li><code>23</code> &rarr; ULEB128. A single byte with the high bit clear, so the value <em>is</em> 0x23 = 35. <code>column = 35</code>.</li>
                </ul>
                <p>Readelf agrees: <code>[0x00000044]  Set column to 35</code>. Six of these appear, with arguments 35, 14, 1, 16, 9, 11, 9, 13, 1 &mdash; and every one of those single-byte arguments decodes the same way. A ULEB128 below 0x80 is just its own value; the multi-byte encoding only kicks in at 128.</p>
                <p><strong><code>DW_LNE_set_address</code> at 0x46</strong> &mdash; the bytes are <code>00 09 02 29 11 00 00 00 00 00</code>:</p>
                <ul>
                    <li><code>00</code> &rarr; not a standard opcode, so this is an <em>extended</em> opcode.</li>
                    <li><code>09</code> &rarr; the block length, 9 bytes, counting everything after this field. So the opcode spans 0x46-0x4f inclusive, which is exactly ten bytes &mdash; the length byte plus nine.</li>
                    <li><code>02</code> &rarr; sub-opcode 2 = <code>set_address</code>.</li>
                    <li><code>29 11 00 00 00 00 00 00</code> &rarr; eight bytes, because <code>address_size = 8</code>, little-endian: <strong>0x1129</strong>.</li>
                </ul>
                <p>Readelf: <code>[0x00000046]  Extended opcode 2: set Address to 0x1129</code>. Note that the length byte is the reason extended opcodes are skippable &mdash; a reader that meets an extended opcode it does not understand can jump <code>length</code> bytes and resynchronise. Standard opcodes have no such escape hatch, which is exactly what <code>standard_opcode_lengths</code> is for.</p>
                <p>One more, because it looks like a mistake and is not. At 0x63 the bytes are <code>00 04 04 01</code>:</p>
                <ul>
                    <li><code>00</code> &rarr; extended.</li>
                    <li><code>04</code> &rarr; block length 4, spanning 0x63-0x67.</li>
                    <li><code>04</code> &rarr; sub-opcode 4 = <code>set_discriminator</code>.</li>
                    <li><code>01</code> &rarr; ULEB value 1.</li>
                </ul>
                <p>Readelf: <code>[0x00000063]  Extended opcode 4: set Discriminator to 1</code>. The discriminator distinguishes multiple line rows for the <em>same</em> address &mdash; which happens when the compiler maps several source positions onto one machine instruction, as it does with short-circuit operators. One instruction, several source lines, disambiguated by an integer.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -gdwarf-5 -O0 -o shape_v5 shape.c
$ readelf --debug-dump=rawline shape_v5 | sed -n '/Line Number Statements/,$p'

$ objcopy --dump-section .debug_line=dl.bin shape_v5
$ xxd -s 0x44 -l 32 dl.bin</code></pre>
                <p>What to look for: the set_column opcodes are all <code>05 xx</code> and the extended opcodes are all <code>00 LL</code>. Confirm that every <code>00</code> you see is followed by a length that lands exactly on the next statement offset readelf printed &mdash; that is the skip rule working.</p>
                <p>Then make the compiler use the opcodes that are currently absent. Turn on optimisation and short-circuit operators, and watch <code>set_discriminator</code> multiply:</p>
                <pre><code>$ cat d.c
int f(int a, int b) &#123; return a &amp;&amp; b + (a ? 1 : 2); &#125;
$ gcc -gdwarf-5 -O0 -o d d.c
$ readelf --debug-dump=rawline d | sed -n '/Line Number Statements/,$p'</code></pre>
                <p>You will see several rows sharing one address, each with a different discriminator. That is the feature the previous concept's table row was pointing at.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: the program contains <code>DW_LNS_advance_pc</code> with the single argument byte <code>02</code>, and <code>minimum_instruction_length</code> is 1. What address change does that opcode produce, and what would the same byte produce on a target where <code>minimum_instruction_length</code> is 4?</p>
                <div class="quiz" id="quiz-dwarf-standard-opcodes-1">
                    <button class="quiz-option" data-correct="true" data-explain="advance_pc multiplies its ULEB argument by minimum_instruction_length, so 2 x 1 = 2 bytes here. With min_inst_len = 4 the same byte means 8 bytes. The opcode is defined in units of the minimum instruction length precisely so the encoding stays valid when that length changes between targets." onclick="checkQuiz('quiz-dwarf-standard-opcodes-1', this)">2 bytes here (2 x 1), and 8 bytes on a target with a minimum instruction length of 4 &mdash; the argument is in units of <code>min_inst_len</code>, not raw bytes</button>
                    <button class="quiz-option" data-correct="false" data-explain="This describes DW_LNS_fixed_advance_pc, which is a different opcode and adds its argument as raw bytes regardless of minimum_instruction_length. DW_LNS_advance_pc is the one at 0x6e in our program, and it is the one that scales." onclick="checkQuiz('quiz-dwarf-standard-opcodes-1', this)">2 bytes here, and still 2 bytes on any target, because the argument is always a raw byte count</button>
                    <button class="quiz-option" data-correct="false" data-explain="A minimum instruction length of 4 would make the advance larger, not smaller. It also cannot be zero: the header value is used as a divisor-style scale, and min_inst_len = 0 is not a legal encoding." onclick="checkQuiz('quiz-dwarf-standard-opcodes-1', this)">2 bytes here, and 1 byte on a target with a minimum instruction length of 4, because 2 is divided by the minimum instruction length</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a line-program reader and hit an opcode byte of <code>0x0d</code> &mdash; thirteen, which is exactly <code>opcode_base</code>. Your code treats anything at or above <code>opcode_base</code> as a special opcode and runs the division and modulo. What is wrong, and what should it do instead?</p>
                <div class="quiz" id="quiz-dwarf-standard-opcodes-2">
                    <button class="quiz-option" data-correct="true" data-explain="Opcodes 1..12 are the standard ones; opcode_base names the first special opcode, and 13 is a valid special opcode value, not a marker. Treating it as the marker throws away a real row: the reader would compute a bogus adjusted_opcode of 0 and emit a row at an address nobody intended. The general rule is: below opcode_base means look up standard_opcode_lengths; at or above it means special-opcode arithmetic." onclick="checkQuiz('quiz-dwarf-standard-opcodes-2', this)">0x0d is a perfectly valid <em>special</em> opcode (adjusted_opcode 0) and must be decoded with the special-opcode rules. The special-opcode range is <code>opcode_base</code> and <em>above</em>, not a sentinel value to be treated as an error or an end marker</button>
                    <button class="quiz-option" data-correct="false" data-explain="It is true that 13 is the first special opcode, but the special-opcode range is inclusive of opcode_base. Nothing about the value 0x0d is special, and treating it as a terminator would silently truncate the line table at that point." onclick="checkQuiz('quiz-dwarf-standard-opcodes-2', this)">0x0d equals <code>opcode_base</code>, so it marks the end of the standard opcode range and the reader should stop there</button>
                    <button class="quiz-option" data-correct="false" data-explain="A vendor may define extended opcodes, but they are reachable only through the DW_LNE escape (a leading 0x00 plus a length), not through a bare byte in the special-opcode range. A bare 0x0d has only one meaning: a special opcode with adjusted_opcode 0." onclick="checkQuiz('quiz-dwarf-standard-opcodes-2', this)">0x0d is an extended opcode from a vendor extension, so the reader should consult the <code>standard_opcode_lengths</code> table even though it equals <code>opcode_base</code></button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: read the bounds from the header, do not hard-code them. <code>opcode_base = 13</code> is a property of this file, not of DWARF, and the same two-branch dispatch works for any file once those three numbers come from the header.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is a bytecode interpreter, and the tradeoffs are the same ones you would make writing any: a table of opcodes, a small register file, and a loop. The <code>op_index</code> register is the same idea as the operation index in <a href="/courses/elf/lessons/entry-point">the ELF entry point</a> concept &mdash; state that lets a variable-length encoding resume mid-instruction.</p>
                <p>The <code>block length</code> on extended opcodes is the same self-describing-length trick as <code>unit_length</code>, for the same reason: a reader must be able to skip what it does not understand. You saw it in <a href="/courses/dwarf/lessons/dwarf-line-header">the .debug_line header</a> and in <a href="/courses/dwarf/lessons/dwarf-versions">DWARF 2, 3, 4 and 5</a>.</p>
                <p>Only two of the twelve standard opcodes appeared in <code>shape_v5</code>. The other ten, and the arithmetic that makes the common case a <em>single byte</em>, are the subject of the next concept.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-special-opcodes">The Special Opcodes</a> &mdash; one byte, two divisions, and the arithmetic that decides the address and the line.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-file-tables">Previous: Directory and File Tables</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-special-opcodes">Next: The Special Opcodes</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
