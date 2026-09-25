// DWARF Course — Module 4: Location and Range Lists, Portability, and Packages
// Concept: .debug_loclists, the DW_LLE table, and a real disagreement between two
// reference readers that only byte offsets can settle.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_loclists() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Location Lists — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Location Lists</h1>
            <div class="lesson-meta">24 min &middot; Module 4: Location Lists, Portability and Packages &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The <a href="/courses/dwarf/lessons/dwarf-locations">previous concept</a> gave you a location expression: a short program that computes where a variable is. It works because it is evaluated <em>at one instant</em>, with the register state of one machine at one program point.</p>
                <p>That assumption breaks in a real optimised function. Consider a parameter that arrives in <code>rdi</code> at function entry, gets spilled to the stack somewhere in the middle of the body, and is loaded into <code>rsi</code> near the end. There is no single expression that is true for the whole function. There are three, and each is true for a different range of instruction addresses.</p>
                <p>A format that could only say <code>DW_OP_reg5</code> would have to lie to a debugger. DWARF's answer is to split the attribute in two: the DIE keeps an <strong>offset into a table</strong>, and the table says "over this address range, this expression". The variable's name, type and scope stay in the DIE where a compiler front end can find them cheaply; only the per-address-range answers move into a side table that a debugger reads on demand.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>First the shape. A <code>DW_AT_location</code> attribute is a <em>form</em> plus a value, and the form is what tells a reader how to interpret the value. You have already seen the <code>exprloc</code> form, where the value is the expression's own bytes. The loclist form looks the same but the value is an offset:</p>
                <table>
                    <thead>
                        <tr><th scope="col">What you see</th><th scope="col">Form</th><th scope="col">Value means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>DW_AT_location : 1 byte block: 55</code></td><td><code>exprloc</code></td><td>The bytes <code>55</code> are the expression</td></tr>
                        <tr><td><code>DW_AT_location : 0x24 (loclist)</code></td><td><code>loclistx</code> or <code>loclist</code></td><td>The number <code>0x24</code> is a byte offset into <code>.debug_loclists</code></td></tr>
                    </tbody>
                </table>
                <p>Both readers in this course print the second form as <code>(loclist)</code> and agree on the offset. That agreement matters more than it sounds: it is the first thing to check, because a reader that misjudges the <em>form</em> will go looking in the wrong section entirely and report a location that looks valid.</p>
                <h3>The table's own header</h3>
                <p>Every list section starts with a header, and the header is not the same as the <code>.debug_info</code> CU header you decoded earlier. From <code>types_O2</code>:</p>
                <div class="hex-dump">
                    <pre>0000: 5c 00 00 00 05 00 08 00 00 00 00 00 00 00 00 00
0010: 04 40 48 01 54 04 48 4e 04 a3 01 54 9f 00 02 03
0020: 03 00 00 00 04 44 44 05 55 93 04 93 04 04 44 48
0030: 06 55 93 04 54 93 04 04 48 4d 09 55 93 04 a3 01
0040: 54 9f 93 04 00 01 00 04 04 15 14 75 00 08 20 24
0050: 08 20 26 32 24 03 10 20 00 00 00 00 00 00 22 00
</pre>
                </div>
                <table>
                    <thead>
                        <tr><th scope="col">Bytes</th><th scope="col">Field</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>5c 00 00 00</code></td><td><code>unit_length</code></td><td>92 &mdash; the whole header plus table is 96 bytes</td></tr>
                        <tr><td><code>05 00</code></td><td><code>version</code></td><td>5. The form <code>loclist</code> and the <code>DW_LLE</code> opcodes exist only from version 5</td></tr>
                        <tr><td><code>08</code></td><td><code>address_size</code></td><td>8</td></tr>
                        <tr><td><code>00</code></td><td><code>segment_selector_size</code></td><td>0. Non-zero only on segmented targets, which are historical</td></tr>
                        <tr><td><code>00 00 00 00</code></td><td><code>offset_entry_count</code></td><td>0 &mdash; and this is where the trouble starts</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-warn">
                    <strong>Why the version number is the safety rail.</strong> In DWARF 4 the equivalent section was <code>.debug_loc</code>, and its entries were different opcodes with different meanings. A <code>DW_LLE</code> stream and a <code>.debug_loc</code> stream are not distinguishable by looking at the bytes. Only the <code>version</code> field says which grammar applies. Any tool that decodes <code>.debug_loclists</code> without reading that field is guessing, and the failure is silent.
                </div>
                <h3>The <code>DW_LLE</code> opcodes</h3>
                <p>Each entry is a one-byte opcode followed by operands, exactly like the line program's standard opcodes you decoded earlier. The nine you need:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Byte</th><th scope="col">Opcode</th><th scope="col">Operands</th><th scope="col">Effect</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>00</code></td><td><code>DW_LLE_end_of_list</code></td><td>none</td><td>End this list. Also: an entry at a referenced offset that is <code>00</code> is an <em>empty</em> list</td></tr>
                        <tr><td><code>01</code></td><td><code>DW_LLE_base_addressx</code></td><td>ULEB128 index</td><td>Set the base address from the location's address table</td></tr>
                        <tr><td><code>02</code></td><td><code>DW_LLE_startx_endx</code></td><td>2 ULEB128 indices</td><td>Range given as two address-table indices</td></tr>
                        <tr><td><code>03</code></td><td><code>DW_LLE_startx_length</code></td><td>ULEB128 + ULEB128</td><td>Start from an index, run for a length</td></tr>
                        <tr><td><code>04</code></td><td><code>DW_LLE_offset_pair</code></td><td>2 ULEB128</td><td>Start and end as offsets from the current base</td></tr>
                        <tr><td><code>05</code></td><td><code>DW_LLE_default_location</code></td><td>exprloc</td><td>The fallback expression, used wherever no range matched</td></tr>
                        <tr><td><code>06</code></td><td><code>DW_LLE_base_address</code></td><td>address</td><td>Set the base address to a literal</td></tr>
                        <tr><td><code>07</code></td><td><code>DW_LLE_start_end</code></td><td>2 addresses</td><td>A literal start and end address</td></tr>
                        <tr><td><code>08</code></td><td><code>DW_LLE_start_length</code></td><td>address + ULEB128</td><td>A literal start and a length</td></tr>
                    </tbody>
                </table>
                <p>The distinction worth pausing on: <code>start_end</code> and <code>offset_pair</code> both describe a range, but one uses <em>absolute addresses</em> and the other uses <em>offsets from a base</em>. In a relocatable <code>.o</code> file, an absolute address is meaningless until the linker has placed the section, so producers that target relocatable output prefer the base-relative forms. This is the same reason <code>.debug_info</code> addresses come from relocations rather than being written down.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Three DIEs in <code>types_O2</code> carry loclist offsets. Both readers name the same three: <code>0x10</code>, <code>0x24</code>, and <code>0x47</code>. Two of them decode cleanly enough to walk by hand.</p>
                <h3>The list at offset 0x10</h3>
                <p>Starting at byte <code>0x10</code>, which is <code>04</code> = <code>DW_LLE_offset_pair</code>:</p>
                <div class="hex-dump">
                    <pre>0010: 04 40 48 01 54   DW_LLE_offset_pair (0x40, 0x48): DW_OP_reg4 RSI
0015: 04 48 4e 04 a3 01 54 9f 00   next entry, then 00 ends the list
</pre>
                </div>
                <p>Read it out. Opcode <code>0x04</code>. Then a ULEB128 <code>0x40</code> = 64, and a ULEB128 <code>0x48</code> = 72 &mdash; those are the start and end offsets. Then the expression, an <code>exprloc</code>: a ULEB128 length <code>01</code>, then one byte <code>54</code> = <code>DW_OP_reg4</code> = <code>rsi</code>. The list is terminated by <code>00</code> at <code>0x1e</code>.</p>
                <p>So the complete statement about this variable is: <em>for code between base+64 and base+72, the value is in <code>rsi</code>; nowhere else in this list is it anywhere.</em> Compare that with the <code>exprloc</code> case in the previous concept, which said only "the value is in <code>rsi</code>" with no address qualifier at all. Same one-byte expression, entirely different reach.</p>
                <h3>The list at offset 0x24, and a value split across registers</h3>
                <div class="hex-dump">
                    <pre>0024: 04 44 44 05 55 93 04 93 04
      04 44 48 06 55 93 04 54 93 04
      04 48 4d 09 55 93 04 a3 01 54 9f 93 04 00
</pre>
                </div>
                <p>Three <code>offset_pair</code> entries and an <code>end_of_list</code>. Decoding the first: <code>04</code>, then <code>44 44</code> &mdash; two single-byte ULEB128s, both <code>0x44</code> = 68, so a <strong>zero-length range at base+68</strong>. A zero-length range is not a mistake: it is how a producer says "at this one point, use the following expression, and do not extrapolate it". The expression is <code>05 55 93 04 93 04</code>: a ULEB128 length of <code>5</code>, then <code>55</code> = <code>DW_OP_reg5</code> = <code>rdi</code>, then <code>93 04</code> = <code>DW_OP_piece</code> with operand <code>4</code>, then <code>93 04</code> again &mdash; <code>DW_OP_piece 4</code> twice.</p>
                <p>What that says: this variable is <strong>eight bytes wide and lives in two registers</strong>. The first four bytes are in <code>rdi</code>, the next four bytes are in whatever the second <code>DW_OP_piece</code> applies to &mdash; and because the expression ended after the two <code>piece</code> opcodes with nothing on the stack, the second piece is undefined in this range. A reader that ignores <code>DW_OP_piece</code> reports the low four bytes as the whole value and is wrong by half the variable's size, silently, for every wide variable in the program.</p>
                <p>The third entry is the interesting one. Its expression is <code>09 55 93 04 a3 01 54 9f 93 04</code>: length <code>9</code>, <code>DW_OP_reg5</code>, <code>DW_OP_piece 4</code>, then <code>a3 01</code> = <code>DW_OP_entry_value</code> with a nested expression <code>DW_OP_reg4</code>, then <code>9f</code> = <code>DW_OP_stack_value</code>, then <code>DW_OP_piece 4</code>. Read left to right: the low four bytes are in <code>rdi</code>; the high four bytes are the value <em>rsi had on entry to the function</em>, not its value now. <code>DW_OP_entry_value</code> asks the debugger to re-run a sub-expression against the entry register state. Without it, the high half is reported as whatever <code>rsi</code> happens to contain later, which is a different number every time you run the program.</p>
                <div class="callout callout-warn">
                    <strong>Where the tools disagree, and how to settle it.</strong> The two reference readers shipped with this course do <em>not</em> agree on this section, and the disagreement is instructive. Run them on the same file:
                    <pre>$ readelf --debug-dump=loc types_O2
$ llvm-dwarfdump --debug-loclists types_O2</pre>
                    <code>readelf</code> reports its first entries at offsets <code>0x0c</code> and <code>0x0e</code>, describes them as "location view pair", then puts real entries at <code>0x10</code> and <code>0x15</code> and ends at <code>0x1d</code>. <code>llvm-dwarfdump</code> reports lists at <code>0x0c</code>, <code>0x0d</code>, <code>0x0e</code>, <code>0x0f</code> (all empty), real entries at <code>0x10</code>, then <code>0x1e</code>, <code>0x23</code>, <code>0x24</code>, <code>0x45</code>.
                    <br /><br />
                    The bytes settle it. At <code>0x0c</code> the four bytes are <code>00 00 00 00</code>. Byte <code>0x00</code> is <code>DW_LLE_end_of_list</code> in DWARF 5, so the list at <code>0x0c</code> is empty and immediately terminated; the same is true at <code>0x0d</code>, <code>0x0e</code> and <code>0x0f</code>. "Location view pair" is a DWARF 4 <code>.debug_loc</code> concept &mdash; it has no meaning in a <code>DW_LLE</code> stream. What <code>readelf</code> is doing is decoding a version-5 <code>DW_LLE</code> table with a version-4 view-pair grammar.
                    <br /><br />
                    You can check without trusting either tool. <code>readelf</code>'s offsets must be a sequential walk of the byte stream. Its second entry claims <code>0x0e</code> and its next <code>0x10</code>, but <code>0x10</code> is four bytes after <code>0x0e</code> and the bytes there are <code>04 40 48 01 54</code> &mdash; an <code>offset_pair</code> with operands <code>0x40</code> and <code>0x48</code>, a five-byte entry. The entry it skipped over was not a two-byte view pair. Meanwhile <code>readelf</code>'s <code>0x1d</code> "end of list" lands in the middle of <code>llvm</code>'s <code>0x1e</code> entry. Every <code>llvm</code> offset is consistent with the bytes; the <code>readelf</code> offsets are not.
                    <br /><br />
                    The lesson is not "binutils is broken". It is that <strong>a format with versioned grammars punishes readers that skip the version field, and the punishment is a plausible table rather than an error.</strong> If you are writing a reader, gate your entry decoding on <code>version == 5</code> and fail loudly otherwise. If you are comparing tools and they disagree about <em>offsets</em> rather than about <em>values</em>, the disagreement is about where entries are, which is checkable by hand from the hex, and the hex wins.
                </div>
                <h3>What <code>offset_entry_count</code> is for</h3>
                <p>Here it is <code>0</code>, which means there is no address table and no index-valued opcode can be used. The header reserves the field for a different layout: a table of start and end <em>addresses</em> at the front of the section, which lets <code>DW_LLE_startx_endx</code> name a range by index instead of writing two full addresses. A producer that wants the indirection writes a non-zero count, and a reader that assumes zero will read the address table as if it were entries. Like every other count in this format, the value tells you the shape of everything that follows.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a debugger actually does when you ask for a variable's value at a given address. The loop is short, and every step is a decision the previous concept already gave you the vocabulary for:</p>
                <div class="formula">
loclists_header = read_header_at(section_start)
entry           = start at the offset the DIE gave you
base            = 0

while true:
    opcode = read_uleb_or_byte at entry
    if opcode == DW_LLE_end_of_list:
        stop
    if opcode == DW_LLE_offset_pair:
        start_offset = read_uleb128
        end_offset   = read_uleb128
        if start_offset &lt;= target - base and target - base &lt; end_offset:
            location_expression = read_exprloc
            stop
    if opcode == DW_LLE_base_addressx:
        base = address_table[read_uleb128]
    if opcode == DW_LLE_start_end:
        start_address = read_address
        end_address   = read_address
        if start_address &lt;= target and target &lt; end_address:
            location_expression = read_exprloc
            stop
    if opcode == DW_LLE_default_location:
        remember_this_as_the_fallback
</div>
                <p>Two things in that loop are worth naming. The range test is <strong>half-open</strong>: <code>start &lt;= target &lt; end</code>. A zero-length range like the one at <code>0x24</code> therefore matches <em>nothing</em>, which is exactly the point &mdash; it is a marker for a single instruction, and the debugger reaches it by scanning rather than by searching. And the <code>base</code> variable is the mechanism that makes <code>offset_pair</code> work: entries before the first base-setting opcode are relative to whatever base was established earlier, and a reader that resets <code>base</code> per list rather than per section mis-resolves every list that does not set its own.</p>
                <p>Now the payoff, connecting to the earlier concepts. The expression you end up holding is <code>54</code> &mdash; one byte, <code>DW_OP_reg4</code>. You then read the <em>register file</em>, not memory. So a location list plus a location expression touches three subsystems that the format keeps deliberately separate: the DIE for the name and type, <code>.debug_loclists</code> for the address ranges, and the live machine state for the value. That separation is why the same debug info can describe a program that is not running yet, and why a debugger can show you a variable in a core dump where no register file exists except the one the dump preserved.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ llvm-dwarfdump --debug-loclists types_O2
$ readelf --debug-dump=loc types_O2
$ readelf --debug-dump=info types_O2 | grep -A1 DW_AT_location</code></pre>
                <ul>
                    <li><strong>Reproduce the disagreement and adjudicate it.</strong> Run both dumps on <code>types_O2</code>. Then hand-walk the first four bytes at <code>0x0c</code> in your hex viewer and decide for yourself which reader is walking the stream correctly. The test that settles it: take each tool's reported offsets in order and check that each entry's byte length actually reaches the next one.</li>
                    <li><strong>Find a <code>DW_OP_piece</code> that is not a whole variable.</strong> The list at <code>0x24</code> is a wide value in two registers. Identify which part of the source variable each <code>piece</code> covers &mdash; you can tell from the two piece sizes summing to the variable's <code>DW_AT_byte_size</code>.</li>
                    <li><strong>Find a <code>DW_OP_entry_value</code> and work out what it needs.</strong> It is a nested expression evaluated against the function's <em>entry</em> register state, not the current one. To evaluate it you need the register values at function entry, which is not something the current state contains. Ask yourself where a debugger gets that, and what it does if the answer is "it doesn't know".</li>
                    <li><strong>Produce a case with <code>DW_LLE_start_end</code> or a non-zero <code>offset_entry_count</code>.</strong> This compiler emits <code>offset_pair</code> and leaves the count at zero. Try a different <code>-gdwarf-</code> version, a different target, or a hand-built <code>.o</code>, and check which of the nine opcodes you can actually provoke. Knowing which opcodes you have <em>never</em> seen is worth as much as knowing the ones you have.</li>
                    <li><strong>Write the lookup loop above and test it.</strong> The decoder shipped with this course walks every DWARF section it knows; extend it with <code>.debug_loclists</code> and check that your table's entry offsets agree with <code>llvm-dwarfdump</code>'s. If they do not, the <code>version</code> check is the first thing to add.</li>
                </ul>
                <p>And a check on your own work: the section is 96 bytes, <code>unit_length</code> says 92, and the highest entry <code>llvm-dwarfdump</code> reports starts at <code>0x45</code>. A table whose last entry starts 37 bytes before the end is not truncated &mdash; it has a long expression at the end. If your decoder runs out of input before <code>0x45</code>, you have mis-sized an entry, most likely by reading a ULEB128 operand as a fixed-width one.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a <code>DW_AT_location</code> attribute in the <code>-O2</code> build reads <code>0x24 (loclist)</code>. What is stored at offset <code>0x24</code>, and what does a debugger have to do to use it?</p>
                <div class="quiz" id="quiz-dwarf-loclists-1">
                    <button class="quiz-option" data-correct="true" data-explain="The loclist form means the value is an offset into .debug_loclists, not an expression. Offset 0x24 holds a list of offset_pair entries: the first is a zero-length range whose expression is DW_OP_reg5 followed by two DW_OP_piece 4 opcodes, describing an eight-byte value in two registers at one point in the code. To use it a debugger finds the entry whose half-open range contains the address being asked about, takes that entry's expression, and evaluates it. The form is the thing to check first: a reader that treats 0x24 as expression bytes goes to the wrong section and produces a plausible wrong value." onclick="checkQuiz('quiz-dwarf-loclists-1', this)">A table of address ranges and expressions. A debugger looks up the range containing the address it wants, takes that range's expression, and evaluates it. The first entry here is a zero-length range holding a <code>DW_OP_piece</code> pair, meaning an eight-byte value in two registers</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x24 is the attribute's value, not a section offset the reader computes. The form tells the reader where to go: loclist or loclistx means the value indexes into .debug_loclists, and the reader then does the range lookup itself." onclick="checkQuiz('quiz-dwarf-loclists-1', this)">The bytes of a location expression, and the debugger evaluates it directly as in the <code>exprloc</code> case</button>
                    <button class="quiz-option" data-correct="false" data-explain="A zero-length range matches no address under the half-open test start &lt;= target &lt; end, so it is not returned by a search. It is a marker for a single instruction, reached by scanning the list in order. A reader that searched for it by range would find nothing and fall through to a wrong location." onclick="checkQuiz('quiz-dwarf-loclists-1', this)">A base address, so that every later range in the section is relative to it</button>
                    <button class="quiz-option" data-correct="false" data-explain="This inverts the indirection. The base address exists so that entries can be written as small offsets from a base, which is what makes the table relocatable and compact. The address table, when one exists, is a separate structure whose size is given by offset_entry_count, and it is empty here because that count is zero." onclick="checkQuiz('quiz-dwarf-loclists-1', this)">An entry in the section's address index table, which the reader dereferences to find the real range</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a DWARF reader for a tool that has to work on binaries from many producers. It works perfectly on <code>.debug_info</code> and <code>.debug_line</code>. On DWARF 5 binaries it reports locations that are the right shape and the wrong value, and the wrongness is confined to variables that have a <code>loclist</code> &mdash; every <code>exprloc</code> variable is correct. The two reference readers on this machine also disagree about this same section, and you have verified the bytes yourself. What is the most likely cause, and what is the smallest change that would confirm it?</p>
                <div class="quiz" id="quiz-dwarf-loclists-2">
                    <button class="quiz-option" data-correct="true" data-explain="The symptom is diagnostic on its own. Only loclist variables are wrong, and exprloc variables are right, so the DIE parsing, the form decoding, the expression evaluator and the section reader are all fine. What is left is the loclist table walk. Both reference readers disagree here, and readelf's output names DWARF 4 view pairs inside a version-5 section, which is the signature of a version gate that is missing or not being enforced. A reader that decodes DW_LLE opcodes without checking version == 5 uses the wrong opcode grammar, and because the wrong grammar still consumes a plausible number of bytes, the failure is a plausible table rather than an error." onclick="checkQuiz('quiz-dwarf-loclists-2', this)">The loclist table walk is using the DWARF 4 <code>.debug_loc</code> grammar on a DWARF 5 <code>DW_LLE</code> stream, because the reader never checked the section's <code>version</code> field. Adding a hard check that <code>version == 5</code> before decoding entries would turn the current silent wrongness into either a fix or an explicit failure</button>
                    <button class="quiz-option" data-correct="false" data-explain="This would affect every variable, not just the loclist ones. The reported symptom is that exprloc variables are correct, which rules out the shared expression evaluator. A SLEB128 sign bug is a good general suspicion, but it is excluded by exactly the evidence given here." onclick="checkQuiz('quiz-dwarf-loclists-2', this)">The <code>exprloc</code> evaluator is fine but the SLEB128 operand decoder is unsigned, which happens to cancel out for simple <code>fbreg</code> cases and only shows up in the loclist expressions</button>
                    <button class="quiz-option" data-correct="false" data-explain="Relocations are how a relocatable .o gets real addresses, and the detail that would break is reading raw bytes where relocations have not been applied. But the evidence points elsewhere: a relocatable object would break addr, loclist and DIE-address reads together, not cleanly separate the loclist variables from every other variable." onclick="checkQuiz('quiz-dwarf-loclists-2', this)">The reader is reading the raw bytes of a relocatable <code>.o</code> without applying the relocations, so the base addresses in the table are zeros</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a failure is confined to one feature, suspect the thing unique to that feature, not the machinery it shares. And when two readers disagree, the bytes are the tie-breaker &mdash; check that each tool's reported offsets are reachable by sequentially consuming the bytes it claims.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Location lists answer <em>where in the code</em> a value is. The sibling question &mdash; <em>where in the address space does a block of code live</em> &mdash; is asked by the linker and the unwinder, and it has the same shape. <code>DW_AT_ranges</code> points into a <code>.debug_rnglists</code> table built from the same nine-opcode idea, and the next concept decodes one. The two sections share a header layout, a version-gated opcode set, and the same trap: they were introduced in DWARF 5 and replace something from DWARF 4, so a reader that does not check the version will happily produce a table of the wrong shape.</p>
                <p>The <code>DW_OP_entry_value</code> opcode introduced here is the one place DWARF reaches backwards: it asks for an expression evaluated against the state at function entry, which is a machine-register concept. That is the same join as <a href="/courses/dwarf/lessons/dwarf-frames">call frame information</a>, which is how a debugger gets the register values at a call boundary in the first place.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-rnglists">Range Lists</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-lookup">Previous: Putting a Lookup Together</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-rnglists">Next: Range Lists</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
