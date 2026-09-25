// DWARF Course — Module 4: Location and Range Lists, Portability, and Packages
// Concept: .debug_rnglists and DW_AT_ranges — the same table idea as loclists,
// answering "which addresses does this code occupy" instead of "where is this value".
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_rnglists() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Range Lists — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Range Lists</h1>
            <div class="lesson-meta">19 min &middot; Module 4: Location Lists, Portability and Packages &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Some code occupies one contiguous run of addresses. Most code does not. A <a href="/courses/dwarf/lessons/dwarf-scopes">function with an inlined subroutine</a> inside it has a body, then the inlined body, then more of the original body &mdash; and a debugger asked "which source line is at address 0x2008" has to know that the middle stretch belongs to a different file and a different <code>DW_TAG</code> than the code on either side of it.</p>
                <p>A single <code>DW_AT_low_pc</code> plus <code>DW_AT_high_pc</code> cannot express that. The format does not pretend otherwise: it gives the <em>set</em> of ranges as a table, and the attribute that points at it is <code>DW_AT_ranges</code>, whose form is an offset into <code>.debug_rnglists</code>. The table is a list of half-open address intervals, and the meaning is the same everywhere in DWARF: a DIE describes code over a set of ranges, not one address.</p>
                <p>This is the second half of a pattern the previous concept started. <code>.debug_loclists</code> says where a <em>value</em> is, per code range. <code>.debug_rnglists</code> says what <em>code</em> is there. Same header, same idea, different question &mdash; and, as you will see, nearly the same bytes.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two ways for a DIE to say "this applies here", and the choice between them is a question about how fragmented the code is:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Attributes</th><th scope="col">Means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>DW_AT_low_pc</code> + <code>DW_AT_high_pc</code></td><td>One contiguous interval. Two numbers inline in the DIE, no table needed</td></tr>
                        <tr><td><code>DW_AT_low_pc</code> + <code>DW_AT_ranges</code></td><td>Starts at <code>low_pc</code>, and the range table gives the intervals <em>relative to it</em></td></tr>
                        <tr><td><code>DW_AT_ranges</code> alone</td><td>The table gives absolute base addresses itself, via <code>DW_RLE_base_address</code></td></tr>
                    </tbody>
                </table>
                <p>The middle row is the one that confuses people, because it looks like the offsets in the table are absolute addresses and they are not. When <code>low_pc</code> is present, it is the base, and every <code>offset_pair</code> in the list is measured from it. A file that has both attributes and a reader that adds <code>low_pc</code> twice produces ranges that are correct-looking and wrong by a constant &mdash; which is the worst kind of wrong, because the table still has plausible intervals in it.</p>
                <h3>The nine <code>DW_RLE</code> opcodes</h3>
                <p>They are numbered identically to the <code>DW_LLE</code> opcodes you just decoded, and they mean the same things:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Byte</th><th scope="col">Opcode</th><th scope="col">Effect on a range list</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>00</code></td><td><code>DW_RLE_end_of_list</code></td><td>End the list</td></tr>
                        <tr><td><code>01</code></td><td><code>DW_RLE_base_addressx</code></td><td>Base := address table[index]</td></tr>
                        <tr><td><code>02</code></td><td><code>DW_RLE_startx_endx</code></td><td>Add the range address[index1], address[index2]</td></tr>
                        <tr><td><code>03</code></td><td><code>DW_RLE_startx_length</code></td><td>Add the range address[index], and that plus a length</td></tr>
                        <tr><td><code>04</code></td><td><code>DW_RLE_offset_pair</code></td><td>Add base+start, base+end</td></tr>
                        <tr><td><code>05</code></td><td><code>DW_RLE_base_address</code></td><td>Base := the literal address that follows</td></tr>
                        <tr><td><code>06</code></td><td><code>DW_RLE_start_end</code></td><td>Add the literal range that follows</td></tr>
                        <tr><td><code>07</code></td><td><code>DW_RLE_start_length</code></td><td>Add the literal start that follows, and that plus a length</td></tr>
                    </tbody>
                </table>
                <p>Eight opcodes, not nine: a range list has no <code>default_location</code>, because there is no default expression to fall back to. That is the <em>only</em> structural difference in the opcode set, and it is the whole difference between the two sections' tables.</p>
                <div class="callout callout-warn">
                    <strong>There is no <code>DW_RLE_offset_pair</code> in DWARF 4.</strong> Before version 5, ranges lived in <code>.debug_ranges</code> and used a completely different set of opcodes (<code>DW_RLE_end_of_list</code> and <code>DW_RLE_base_addressx</code> existed, but the interval entries did not). Since the version 5 opcodes overlap numerically with the old ones, a reader that skips the version field will parse version-4 data using version-5 meanings and produce a table of intervals that are individually well-formed and collectively wrong. Same trap as the previous concept, same defence: gate on the version.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Take <code>inline_O2.o</code> &mdash; the object file built from <code>inline.c</code> at <code>-O2</code>, where a function was inlined. It is the smallest case on this machine that actually has range lists:</p>
                <div class="hex-dump">
                    <pre>0000: 4a 00 00 00 05 00 08 00 00 00 00 00 05 00 00 00
0010: 00 00 00 00 00 04 00 12 04 12 1a 04 22 30 04 38
0020: 3c 00 05 00 00 00 00 00 00 00 00 04 00 00 04 08
0030: 10 04 1e 26 04 2a 2e 00 07 00 00 00 00 00 00 00
0040: 00 89 01 07 00 00 00 00 00 00 00 00 0a 00
</pre>
                </div>
                <p>Seventy-eight bytes, and every one of them is accounted for. The header is twelve bytes, identical in layout to the loclists header from the previous concept:</p>
                <div class="hex-dump">
                    <pre>0000: 4a 00 00 00   unit_length = 74
0004: 05 00         version = 5
0006: 08            address_size = 8
0007: 00            segment_selector_size = 0
0008: 00 00 00 00   offset_entry_count = 0
000c:  &lt;- the first range entry starts here
</pre>
                </div>
                <p>And the <code>DW_AT_ranges</code> attribute in the inlined subroutine's DIE reads <code>0xc</code> &mdash; pointing at exactly that first byte. Now walk the list:</p>
                <div class="hex-dump">
                    <pre>000c: 05                    DW_RLE_base_address
000d: 00 00 00 00 00 00 00 00  base = 0  (a relocation supplies the real value)
0015: 04 00 12              DW_RLE_offset_pair (0, 18)
0018: 04 12 1a              DW_RLE_offset_pair (18, 26)
001b: 04 22 30              DW_RLE_offset_pair (34, 48)
001e: 04 38 3c              DW_RLE_offset_pair (56, 60)
0021: 00                    DW_RLE_end_of_list
</pre>
                </div>
                <p>Now the part that trips people up. The byte after that <code>end_of_list</code> is <code>05</code> at <code>0x22</code>, which is a second <code>DW_RLE_base_address</code>. And after <em>that</em> list ends at <code>0x37</code>, a third list begins at <code>0x38</code>. So this section holds <strong>three</strong> independent tables, back to back:</p>
                <div class="hex-dump">
                    <pre>0022: 05                    DW_RLE_base_address
0023: 00 00 00 00 00 00 00 00  base = 0  (relocated again)
002b: 04 00 00              DW_RLE_offset_pair (0, 0)
002e: 04 08 10              DW_RLE_offset_pair (8, 16)
0031: 04 1e 26              DW_RLE_offset_pair (30, 38)
0034: 04 2a 2e              DW_RLE_offset_pair (42, 46)
0037: 00                    DW_RLE_end_of_list
0038: 07                    DW_RLE_start_length
0039: 00 00 00 00 00 00 00 00  start address = 0  (relocated)
0041: 89 01                 length = 137   (a ULEB128 with two bytes)
0043: 07                    DW_RLE_start_length
0044: 00 00 00 00 00 00 00 00  start address = 0  (relocated)
004c: 0a                    length = 10    (a single-byte ULEB128)
004d: 00                    DW_RLE_end_of_list
</pre>
                </div>
                <p>That is worth internalising: <code>DW_AT_ranges</code> points at the start of <strong>one</strong> list, and running off its <code>end_of_list</code> lands you on another DIE's list, not on the end of the section. Three tables, no table of contents, and nothing in the file says how many there are. A decoder that treats the section as one stream merges three unrelated tables into one and produces a set of intervals that belong to no single construct.</p>
                <p>Notice also that the third list uses a <em>different</em> opcode family. The first two express ranges as offsets from a base; the third writes literal start addresses with lengths. Both are legal, in the same file, in the same section. And the length in the first entry is <code>89 01</code> &mdash; two bytes, because <code>0x89</code> has its high bit set and the value continues in <code>0x01</code>: <code>0x09 | (0x01 &lt;&lt; 7)</code> = <code>137</code>. The second is <code>0a</code> = 10 in one byte. ULEB128 is variable-width in the middle of a list, not just at its head.</p>
                <h3>Why the base address is zero in the file</h3>
                <p>The eight bytes at <code>0x0d</code> are all zero, and the real base address is not zero. This is an object file: it has not been placed anywhere yet. The value is supplied by a relocation, and the section has its own relocation section:</p>
                <pre><code>$ readelf -S -W inline_O2.o | grep rnglists
 [12] .debug_rnglists   PROGBITS  0000000000000000 0004dc 00004e 00  0 0 1
 [13] .rela.debug_rnglists RELA   0000000000000000 000ce8 000060 18  I 13 12 8</code></pre>
                <p>Note the size: <code>0x4e</code> = 78 bytes, matching the hex dump exactly, and <code>0x60</code> = 96 bytes of relocations &mdash; eight 24-byte <code>Elf64_Rela</code> entries. The same lesson as <a href="/courses/dwarf/lessons/dwarf-split">the split-debugging concept</a>: in a relocatable object, an address in a debug section is not a number, it is a <em>placeholder for</em> a number.</p>
                <p>So when you read this table with a tool, the answer depends on whether the tool applied the relocations. <code>llvm-dwarfdump</code> does, and prints the resolved intervals:</p>
                <pre><code>$ llvm-dwarfdump --debug-rnglists inline_O2.o
range list header: length = 0x0000004a, format = DWARF32, version = 0x0005,
                  addr_size = 0x08, seg_size = 0x00, offset_entry_count = 0x00000000</code></pre>
                <p>and <code>readelf --debug-dump=rnglists</code> prints nothing at all for this file. Two reference tools, one of them useful and one of them silent &mdash; and a third reader, the one shipped with this course, that walks the raw bytes. All three agree on the version, the address size, the count, and the three list boundaries. The intervals themselves can only be checked after relocations are applied, so on the object file that claim is not independently verifiable &mdash; which is exactly why the linked binary is the right place to read ranges from.</p>
                <div class="callout">
                    <strong>How to read a claim you cannot fully verify.</strong> "The offsets are 18, 26, 34 and 48" is verifiable from the file and everyone agrees. "The addresses are 0x1234 to 0x1246" is not verifiable from this object, because those numbers are not in it. A course has to say which of the two it is asserting, and must not present the second while showing evidence for the first. When the honest move is to link the object and read the result, the honest move is to link the object.
                </div>
                <h3>The shape of the answer</h3>
                <p>Look at the four intervals the table encodes, as offsets from the base: <code>0&ndash;18</code>, <code>18&ndash;26</code>, <code>34&ndash;48</code>, <code>56&ndash;60</code>. Those are <em>four separate runs</em> of code attributed to one DIE, with gaps at <code>26&ndash;34</code> and <code>48&ndash;56</code> that belong to something else. That is the signature of inlined code: the compiler has interleaved the inlined subroutine's instructions with the caller's, so no single contiguous interval describes them. Had the compiler not inlined, this DIE would have carried <code>low_pc</code> and <code>high_pc</code> and this section would not exist at all.</p>
                <p>One more detail that is easy to miss: a range list is <strong>not sorted, and not necessarily non-adjacent</strong>. The format permits any order, and a reader that binary-searches the table for a target address will be wrong. The tables this compiler emits happen to be ascending, which is a property of the producer, not of the format. A debugger that stops at <code>end_of_list</code> and gives up has also stopped early &mdash; ranges can continue in a different list reached through a base-address entry.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Given an address, find the DIE that describes the code there. The naive approach &mdash; walk every subprogram DIE, read its range, test containment &mdash; works but is quadratic in the number of DIEs. The table exists so you can do better, and the improvement is the practical reason to care about the format.</p>
                <p>First, the containment test itself, with the same half-open rule as location lists:</p>
                <div class="formula">
target = the address being looked up

for each range in the DIE's list:
    if range.start &lt;= target and target &lt; range.end:
        this DIE describes the code at target
        stop
</div>
                <p>Then the part that makes it fast. Ranges are stored relative to a base, and the base is constant across a run of entries. So a table is really a sequence of <em>segments</em>: a base, then a batch of intervals relative to it. If you build, per base, a sorted list of intervals, then one binary search over the segment whose base is nearest below the target finds the answer. Building that index once per compilation unit is what turns a linear scan over every DIE into a lookup.</p>
                <p>Now put the two list types together, because they answer the same question at different levels:</p>
                <div class="formula">
address 0x2008 in a function
    |
    +-- which DIE owns this code?   -> .debug_rnglists, via DW_AT_ranges
    |                                  (inlined subroutine B, not the caller)
    |
    +-- which line in B's source?     -> .debug_line
    |
    +-- what is variable 'x' here?    -> .debug_loclists, via DW_AT_location
    |
    +-- what is the value of 'x'?     -> the location expression
    |                                  (DW_OP_reg4, so: read rsi)
    |
    +-- what is the type of 'x'?      -> .debug_info, follow DW_AT_type
</div>
                <p>Each arrow is a different section and a different lookup algorithm, and all of them are keyed on the same address. That is the architecture of a debugger, and it is worth being able to state it from memory: the address is the join key, and the sections are indexed by it in different ways. The bug you will spend the most time on is almost always in the <em>first</em> arrow, because an answer from the wrong DIE looks exactly like an answer from the right one until you check a value against a breakpoint you set by hand.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ llvm-dwarfdump --debug-rnglists inline_O2.o
$ readelf --debug-dump=info inline_O2.o | grep -B4 DW_AT_ranges
$ readelf -r -W inline_O2.o | grep -A4 debug_rnglists</code></pre>
                <ul>
                    <li><strong>Link the object and compare.</strong> This is the experiment that turns a partial claim into a complete one. Link <code>inline_O2.o</code> into an executable, then run <code>llvm-dwarfdump --debug-rnglists</code> on the executable. The base addresses will be real, and you can check each resolved interval against the <code>objdump -d</code> disassembly &mdash; do the four ranges correspond to four real runs of instructions, with real gaps between them?</li>
                    <li><strong>Relocate the ranges by hand.</strong> Find the relocations that target <code>.debug_rnglists</code>, apply them to the two <code>DW_RLE_base_address</code> fields yourself, and check you get the same intervals the tool prints. This is the same exercise as for addresses in <code>.debug_info</code>, on a section you have not seen before, and it is the general skill.</li>
                    <li><strong>Find the gap and identify what is in it.</strong> The table has gaps at offsets 26&ndash;34 and 48&ndash;56. Disassemble the corresponding addresses in the linked binary and find the DIE that owns those instructions. It is very likely the enclosing subprogram, which is the clearest possible demonstration that one address can belong to a nested DIE.</li>
                    <li><strong>Provoke the opcodes that are still missing.</strong> This build gave you three of the four interval forms in one section: <code>base_address</code> and <code>offset_pair</code> in the first two lists, <code>start_length</code> in the third. Still unobserved here are <code>DW_RLE_start_end</code> and the three index forms <code>base_addressx</code>, <code>startx_endx</code> and <code>startx_length</code>, which need a non-zero <code>offset_entry_count</code> that no configuration on this machine produces. Keep a list of the opcodes you have <em>never</em> seen produced; that list is the honest boundary of what you have tested.</li>
                    <li><strong>Check the <code>low_pc</code> double-count.</strong> Find a DIE that has both <code>DW_AT_low_pc</code> and <code>DW_AT_ranges</code>. Add the offsets to <code>low_pc</code>, then also add it a second time, and see which of the two answers puts the code in a function that disassembles sensibly. That is the fastest way to internalise what "relative to" means.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a DIE carries <code>DW_AT_ranges: 0xc</code> and no <code>DW_AT_low_pc</code>. The byte at offset <code>0xc</code> in the section is <code>05</code>. What does that one byte commit the reader to, and what would a reader get wrong if it assumed the following pairs were absolute addresses?</p>
                <div class="quiz" id="quiz-dwarf-rnglists-1">
                    <button class="quiz-option" data-correct="true" data-explain="0x05 is DW_RLE_base_address, and it is followed by a full address_size-wide literal address, here eight zero bytes that relocations fill in. Because the opcode set the base explicitly, there is no low_pc to add, and every following offset_pair is relative to that base alone. A reader that treated the pairs as absolute would produce intervals starting at address 0 and 18 and 34, which is not merely off by a constant but off by the entire base address, and the resulting table would attribute code to no function at all." onclick="checkQuiz('quiz-dwarf-rnglists-1', this)">It is <code>DW_RLE_base_address</code>, so an eight-byte base address follows it and every later <code>offset_pair</code> is measured from that base. A reader treating the pairs as absolute would be wrong by the whole base address, and would place the code at address 0</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x00 is end_of_list and would make the list empty, so no code at all would be attributed to the DIE. The byte is 0x05. Reading it as a terminator is a plausible mistake precisely because an empty list is a legal thing to find, so it produces a table rather than an error." onclick="checkQuiz('quiz-dwarf-rnglists-1', this)">It is <code>DW_RLE_end_of_list</code>, so the list is empty and the DIE describes no code at all</button>
                    <button class="quiz-option" data-correct="false" data-explain="That opcode consumes two address-table indices, and the section's offset_entry_count is 0, so no address table exists and the opcode cannot legitimately appear here. Reading an index into a table that is not there produces a wild address rather than a wrong-but-close one." onclick="checkQuiz('quiz-dwarf-rnglists-1', this)">It is <code>DW_RLE_base_addressx</code>, so the following byte is an index into the section's address table</button>
                    <button class="quiz-option" data-correct="false" data-explain="A length-style opcode takes a start and a length, not two endpoints, and the list this build emits uses offset_pair for every interval. Reading a length as an end address would truncate or extend each interval by the difference between the two, and for the first interval here both are small enough that the result would still look like a plausible code range." onclick="checkQuiz('quiz-dwarf-rnglists-1', this)">It is <code>DW_RLE_start_length</code>, so the following eight bytes are a start address and the next byte is a length</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A colleague sends you a bug report: your tool shows the wrong source line for roughly one function in a large binary, and only in release builds. Debug builds are perfect. You suspect range lists. You have the object files and the linked binary. Lay out the investigation in the order you would actually run it, and say what result would move you to the next hypothesis.</p>
                <div class="quiz" id="quiz-dwarf-rnglists-2">
                    <button class="quiz-option" data-correct="true" data-explain="Debug and release differ in exactly the thing range lists exist to describe: optimization is what fragments code into non-contiguous runs, and at -O0 a subprogram is one contiguous interval that low_pc and high_pc describe perfectly. That narrows the cause to something that only bites on fragmented code before you look at a single byte. The next move is to read the ranges from the linked binary with relocations applied, because that is the only file where the addresses are real, and check each interval against the disassembly. If an interval does not match, the cause is in the table walk; if the intervals are right, the cause is in the lookup that consumes them, such as assuming the intervals are sorted." onclick="checkQuiz('quiz-dwarf-rnglists-2', this)">Start from the asymmetry: only release builds are affected, and release builds are exactly the ones where inlining fragments code, so a <code>low_pc</code>-and-<code>high_pc</code> reader is correct on debug builds and wrong on the fragmented ones. Then read the <code>.debug_rnglists</code> of the <em>linked binary</em> (not the object, where the addresses are zero) and check each interval against the disassembly</button>
                    <button class="quiz-option" data-correct="false" data-explain="The report is about a large release binary, so the range tables live in the debug sections and reading .debug_line tells you nothing about them. The asymmetry is the clue to look at optimization-dependent structures, and line-number programs are present in both builds." onclick="checkQuiz('quiz-dwarf-rnglists-2', this)">Start with the line number program, since wrong source lines could equally be a <code>.debug_line</code> decoding problem, and diff its output between the two builds</button>
                    <button class="quiz-option" data-correct="false" data-explain="A version gate would affect all range lists, not one function, and would not be specific to release builds. The reported pattern is narrow: one function, and only when optimized. That points at data content, not at which grammar is being used to parse it." onclick="checkQuiz('quiz-dwarf-rnglists-2', this)">Check whether the linked binary declares DWARF 5, and if it declares version 4 instead, conclude the reader is applying the wrong opcode grammar to the range table</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a bug appears in only one build configuration, let that asymmetry choose the investigation. Debug and release differ in a small, enumerable set of things, and the difference that matters is almost always the one the format was designed to handle.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Range lists and location lists are the same table with one opcode missing, and the reason the format did that is worth holding onto: the line number program, which you decoded in Module 2, is a third such table, and it too is a list of entries terminated by a zero byte with a header that declares its own version. Three tables, one shape, three different questions. Recognising the shape is most of what it takes to read a fourth.</p>
                <p>The <code>low_pc</code> half of this is the same idea as relocation processing. A <code>low_pc</code> in a <code>.o</code> is zero for the same reason the <code>DW_RLE_base_address</code> here is zero: the code has not been placed. That is why <a href="/courses/coff/lessons/coff-relocations">relocations</a> are not an ELF-course topic with a DWARF footnote &mdash; they are the mechanism on which every address in every debug section depends.</p>
                <p>Both list sections are now decoded, which closes the question of "where is a thing in the program". What remains is the question of whether the debug info is portable at all, and the next concept answers it by producing debug info that is deliberately not what this machine normally makes.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-portability">Same Source, Different Target</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-loclists">Previous: Location Lists</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-portability">Next: Same Source, Different Target</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
