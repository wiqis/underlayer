// DWARF Course — Module 3: DIEs, Types, Scopes, Locations and Frames
// Concept: .debug_aranges and .debug_pubnames — the indexes that make lookup cheap.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_lookup() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Finding Things Without Reading Everything — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Finding Things Without Reading Everything</h1>
            <div class="lesson-meta">18 min &middot; Module 3: DIEs, Types, Scopes and Locations &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You press a breakpoint on a line, the program stops, and the debugger has to show you the value of a local. To do that it must answer two questions: <em>which compilation unit does this address belong to</em>, and <em>which DIE is called this</em>. Both are searches, and the DIE tree is a tree rather than a list, so neither is something you can binary-search.</p>
                <p>DWARF&rsquo;s answer is two index sections. Neither is required to <em>understand</em> the debug info &mdash; you can decode the whole tree and never look at them &mdash; but without them a debugger cannot be interactive, because every question costs a full walk of a section that can be megabytes long.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two indexes, answering the two questions in opposite directions.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Question</th><th scope="col">Key</th><th scope="col">Gives you</th></tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><code>.debug_aranges</code></td>
                            <td>which unit covers this <strong>address</strong>?</td>
                            <td>address</td>
                            <td>the <code>.debug_info</code> offset of the unit</td>
                        </tr>
                        <tr>
                            <td><code>.debug_pubnames</code></td>
                            <td>where is the DIE for this <strong>name</strong>?</td>
                            <td>name</td>
                            <td>the <code>.debug_info</code> offset of the DIE</td>
                        </tr>
                    </tbody>
                </table>
                <p>Both are per-compilation-unit: each unit gets its own set, and each set begins by saying which unit it describes. <code>.debug_aranges</code> does that with a <code>debug_info_offset</code>; <code>.debug_pubnames</code> with an offset <em>and</em> a size, so it can be checked against a unit boundary.</p>
                <p>The one thing to hold onto is that these are <strong>accelerators, not authority</strong>. The offsets they contain point into <code>.debug_info</code> and must be correct, but they are derived data: a debugger that ignored both sections and walked the tree would get the same answers, only slowly. That is a useful thing to know when one of them disagrees with the tree &mdash; the tree wins.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>.debug_aranges</h3>
                <p>The reference binary has two units, so two sets. The whole first set, 48 bytes, with every byte accounted for:</p>
                <div class="hex-dump">
                    <pre>0000: 2c 00 00 00  unit_length = 44
0004: 02 00        version = 2
0006: 00 00 00 00  debug_info_offset = 0
000a: 08           address_size = 8
000b: 00           segment_selector_size = 0
000c: 00 00 00 00  &lt;- FOUR BYTES OF PADDING. The table starts at 0x10, not 0x0c.
0010: 49 11 00 00 00 00 00 00   address = 0x1149
0018: 80 00 00 00 00 00 00 00   length  = 0x80
0020: 00 00 00 00 00 00 00 00   &lt;- terminator
0028: 00 00 00 00 00 00 00 00      (padding to the unit length)

0030: 2c 00 00 00  unit_length = 44
0034: 02 00        version = 2
0036: 0f 02 00 00  debug_info_offset = 0x20f      (the second unit)
003a: 08 00 00     address_size = 8, segment_selector_size = 0
003c: 00 00 00 00  &lt;- padding again
0040: c9 11 00 00 00 00 00 00   address = 0x11c9
0048: 69 00 00 00 00 00 00 00   length  = 0x69
</pre>
                </div>
                <p><code>readelf</code> agrees on every value, and the second set confirms the shape: header at 0x30, <code>debug_info_offset = 0x20f</code>, table at 0x40, first tuple 0x11c9/0x69.</p>
                <div class="callout callout-warn">
                    <strong>The padding, and why it is the most expensive four bytes in DWARF.</strong> The header is eight bytes after <code>unit_length</code>, so the naive expectation is that the tuple table starts at byte 12. <strong>It starts at byte 16.</strong> gcc pads the table up to the tuple size, and a reader that trusts the field list reads the first address as <code>0x114900000000</code> &mdash; a plausible 48-bit value that points nowhere. Nothing downstream complains: the length decodes, the terminator is found, and the answer is simply wrong. This was found because an independently written decoder disagreed with <code>readelf</code>, and it is the reason every other claim in this course was checked the same way. Only an 8-byte address size could be tested here; for a 4-byte address, byte 12 is already aligned, so the padding would be zero &mdash; <em>a prediction, not a measurement.</em>
                </div>
                <p>One more thing about the version: gcc writes <strong>version 2</strong> here even under <code>-gdwarf-5</code>. <code>.debug_aranges</code> is one of the sections DWARF 5 barely touched, so a modern compiler still emits a decade-old format version in it.</p>
                <h3>.debug_pubnames</h3>
                <p>Built with <code>-gpubnames</code>. Two sets, one per unit:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Set</th><th scope="col"><code>debug_info</code> offset</th><th scope="col">size</th><th scope="col">Entries</th></tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>1</td><td>0x0</td><td>527</td>
                            <td><code>0x10d g_nest</code>, <code>0x122 g_count</code>, <code>0x147 g_table</code>, <code>0x15c make_point</code>, <code>0x1a5 walk</code>, <code>0x1d3 sum_table</code></td>
                        </tr>
                        <tr>
                            <td>2</td><td>0x20f</td><td>209</td>
                            <td><code>0x5a walk</code>, <code>0x75 sum_table</code>, <code>0x8a make_point</code>, <code>0xa4 main</code></td>
                        </tr>
                    </tbody>
                </table>
                <p>Each entry is a 4-byte <code>.debug_info</code> offset then a NUL-terminated name, and a zero offset ends the set. Two observations that stop you building something wrong on top of it:</p>
                <ul>
                    <li><strong>It is not sorted.</strong> Set 1 is in DIE order, which for the first unit is roughly declaration order. Set 2 is in a different order again. If you want a binary search you have to sort it yourself, or hash it.</li>
                    <li><strong>It is not just the globals.</strong> <code>g_nest</code>, <code>g_count</code> and <code>g_table</code> are all <code>static</code> in the source, and all three are listed. The set covers named DIEs of interest, not strictly external symbols, so a name lookup can return a variable with no linkage at all &mdash; which is correct, and which a linker-style &ldquo;externals only&rdquo; assumption would miss.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Breakpoint on a line inside <code>make_point</code>, the program stops at address 0x1150, and the debugger wants to print a local. Using only the two indexes:</p>
                <ol>
                    <li><strong>Address to unit.</strong> Scan <code>.debug_aranges</code> for a tuple whose <code>address &le; 0x1150 &lt; address + length</code>. The first set has 0x1149 with length 0x80, and 0x1149 &le; 0x1150 &lt; 0x11c9. Its <code>debug_info_offset</code> is <strong>0</strong> &mdash; so the unit we want starts at the beginning of <code>.debug_info</code>, and only that unit needs decoding.</li>
                    <li><strong>Offset to unit end.</strong> The unit header at 0 says <code>unit_length = 0x20b</code>, so the unit occupies 0x0 to 0x20f. Anything past 0x20f belongs to the second compilation and must not be searched. This bound is why the two units can be decoded independently.</li>
                    <li><strong>Name to DIE.</strong> Scan <code>.debug_pubnames</code> for the string you want. Set 1 contains <code>0x15c make_point</code>, and 0x15c is inside the first unit&rsquo;s range, so the match is valid. If the same name appeared in both sets you would have to use the address from step 1 to choose between them &mdash; which is the whole reason the two indexes have to be used together.</li>
                    <li><strong>DIE to type.</strong> Jump to 0x15c in <code>.debug_info</code>, read its abbrev code, and walk its children. This is <a href="/courses/dwarf/lessons/dwarf-types">the type chain</a>, and it is confined to one unit.</li>
                    <li><strong>DIE to address.</strong> Each variable child&rsquo;s <code>DW_AT_location</code> is a <a href="/courses/dwarf/lessons/dwarf-locations">location expression</a>, and resolving its frame base needs the <a href="/courses/dwarf/lessons/dwarf-frames">CFI</a> for the FDE covering 0x1150.</li>
                </ol>
                <p>Five steps, and note how little was actually read: one aranges tuple, one unit header, one pubnames entry, one subprogram DIE and its children. The other unit&rsquo;s 27 DIEs were never touched, and neither was the string section beyond the entries that matched.</p>
                <div class="callout callout-tip">
                    <strong>Why this is a real design decision and not an optimisation detail.</strong> A large C++ binary can carry tens of thousands of DIEs across hundreds of units. Stepping one line must not mean walking all of them. The indexes make the cost of a debugger operation proportional to the number of units rather than the size of the program, and they are what makes split DWARF viable at all &mdash; because the skeleton file keeps <code>aranges</code>, <code>pubnames</code> and the line program, so the first three steps above work without ever opening the <code>.dwo</code>.
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ readelf --debug-dump=aranges shape
$ readelf --debug-dump=pubnames  shape
$ readelf -S -W shape | grep -E 'aranges|pubnames|pubtypes'</code></pre>
                <p>Experiments, cheapest first:</p>
                <ul>
                    <li><strong>Recompile without <code>-gpubnames</code></strong> and diff the section list: the indexes simply disappear, and the DIE tree is byte-for-byte the same size. That is the proof that they are derived &mdash; they add nothing the tree does not already say.</li>
                    <li><strong>Add a third source file</strong> and confirm a third aranges tuple appears. Watch the aranges unit offsets track the <code>.debug_info</code> unit offsets exactly, in the same order &mdash; the two sections are written together and there is nothing clever linking them.</li>
                    <li><strong>Test the padding claim directly.</strong> The aranges section is 0x60 bytes for two 48-byte units. Subtract the two headers (8 bytes each) and the two terminator tuples (16 bytes each) and the remainder is 8 bytes &mdash; four per unit, which is exactly the padding. Then decode at offset 12 and watch the address come out as <code>0x114900000000</code>.</li>
                    <li><strong>Look for the non-sorted-ness.</strong> Set 1 and set 2 list the same function names in different orders, in the same file. Any code that binary-searches this list without sorting it first will find some names and miss others, with no error either way.</li>
                    <li><strong>Check what <code>pubtypes</code> adds.</strong> With <code>-gpubnames</code> the same run produces a <code>.debug_pubtypes</code> as well, 0xe4 bytes, indexing types by name. It is the same structure answering the same question about a different kind of DIE.</li>
                </ul>
                <p>And the check for a debugger you are building: if a name lookup and a full tree walk ever disagree, the tree is right. These sections are hints, and a hint that is wrong should cost a slow answer, never a wrong one.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a debugger stops at 0x1150 and wants the DIE for <code>make_point</code>. The <code>.debug_aranges</code> tuple says <code>address 0x1149, length 0x80, debug_info_offset 0</code>. Does that tell you where <code>make_point</code> is?</p>
                <div class="quiz" id="quiz-dwarf-lookup-1">
                    <button class="quiz-option" data-correct="true" data-explain="The aranges tuple answers a different question: which compilation unit covers this address, and it points at offset 0, the start of the first unit. It says nothing about which DIE is which function - that is what .debug_pubnames is for, and here it gives 0x15c. The two indexes are used in sequence, and each answers only the question it was built for." onclick="checkQuiz('quiz-dwarf-lookup-1', this)">No &mdash; it says only that address 0x1150 is inside the compilation unit that begins at <code>.debug_info</code> offset 0. To find the DIE for <code>make_point</code> you need <code>.debug_pubnames</code>, which gives 0x15c</button>
                    <button class="quiz-option" data-correct="false" data-explain="debug_info_offset names the unit, not a DIE inside it, and the first DIE at that offset is the compile unit itself rather than a function. Reading a function DIE out of an aranges tuple would require the table to store DIE offsets, which is precisely the job pubnames does instead." onclick="checkQuiz('quiz-dwarf-lookup-1', this)">Yes &mdash; the tuple points at the DIE for the function covering that address, so <code>make_point</code> is the DIE at <code>.debug_info</code> offset 0</button>
                    <button class="quiz-option" data-correct="false" data-explain="The length is there so the tuple can be tested with address &le; pc &lt; address + length, which is how the right unit is found at all. It describes the extent of the unit's code, not the size of any one function, and reading it as a function size is a category error rather than a decoding slip." onclick="checkQuiz('quiz-dwarf-lookup-1', this)">Yes &mdash; because 0x1150 falls inside 0x1149 to 0x11c9, the function must be <code>make_point</code>, the only subprogram the aranges section knows about</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your debugger resolves most variable names instantly but occasionally reports &ldquo;no symbol named <code>foo</code>&rdquo; for a function that definitely exists, and the failure is not reproducible. The <code>.debug_pubnames</code> section is present and non-empty. What is the most likely cause, and what is the smallest change that makes it correct?</p>
                <div class="quiz" id="quiz-dwarf-lookup-2">
                    <button class="quiz-option" data-correct="true" data-explain="The two sets in the reference binary list the same function names in different orders, so the list is not sorted. A binary search over unsorted data finds a name most of the time and misses it occasionally, with no error - which is exactly the reported symptom. The smallest correct fix is to sort or hash the entries once at load time, keeping the section order untouched, since it is a derived index and nothing else depends on its order." onclick="checkQuiz('quiz-dwarf-lookup-2', this)">The lookup assumes <code>.debug_pubnames</code> is sorted and binary-searches it, but it is not. Sort the entries (or hash them) once at load time &mdash; the section&rsquo;s order carries no meaning, so changing it locally is safe</button>
                    <button class="quiz-option" data-correct="false" data-explain="Duplicate names across units are expected and are resolved by first finding the right unit with aranges, which is the correct use of the two sections together. That would produce a consistent wrong choice for a given unit rather than an intermittent failure, so it does not match a symptom that comes and goes." onclick="checkQuiz('quiz-dwarf-lookup-2', this)">The same name appears in more than one compilation unit&rsquo;s pubnames set, and the lookup takes the first match rather than the one belonging to the current address</button>
                    <button class="quiz-option" data-correct="false" data-explain="The pubnames entries point at the same DIEs the tree walk would find, so a stale or partially built index would disagree with the tree rather than produce a sporadic miss. Since the section is present and non-empty, and the tree walk is the fallback a correct debugger would still consult, the intermittency points at the search algorithm rather than the data." onclick="checkQuiz('quiz-dwarf-lookup-2', this)">The index is stale relative to the <code>.debug_info</code> it points into, because the two were written by different runs of the compiler</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: an intermittent lookup failure is nearly always a search bug, not a data bug. Data that is wrong is wrong consistently &mdash; and an index that is present and wrong will eventually disagree with the authoritative source, which is the one thing you should always be able to fall back to.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>An index that maps a key to an offset, so the reader can seek instead of scanning, appears in every format in these courses. ELF has <code>.symtab</code> and <code>.dynsym</code>, and its <a href="/courses/elf/lessons/dynamic-section">dynamic linking</a> concept depends on the dynamic symbol table being resolvable by name at load time. The <a href="/courses/pe/lessons/pe-imports">PE import directory</a> is a three-level lookup &mdash; import table, name table, IAT &mdash; that exists for the same reason. The COFF course&rsquo;s <a href="/courses/coff/lessons/coff-archives">archive container</a> has a symbol index whose entire purpose is to let a linker answer &ldquo;which member defines this symbol&rdquo; without opening every member.</p>
                <p>What is different about DWARF&rsquo;s indexes is that they are strictly optional and strictly derived. Nothing in the format <em>requires</em> a debugger to read <code>.debug_aranges</code>, and the ELF symbol table is a different animal: it is the authority, not a hint. Learning to tell those two apart &mdash; index versus source of truth &mdash; is what lets a tool degrade gracefully instead of failing.</p>
                <p>That closes Module 3, and with it the DWARF course as written. The tree, the types, the scopes, the locations, the frames and now the indexes are the whole of what a debugger reads on an ordinary ELF binary.</p>
                <p>What remains is specified in <code>courses/dwarf/research.md</code> and deliberately not written: <code>.debug_rnglists</code> and the contents of <code>DW_AT_ranges</code>, the <code>.debug_loclists</code> entry encoding, <code>address_size</code> 4, and the pre-DWARF-5 string forms. The <code>.debug_loclists</code> omission is the notable one, and it is a decision rather than an oversight &mdash; see the next paragraph.</p>
                <p><strong>A note on what is deliberately absent.</strong> <code>.debug_loclists</code> appears at <code>-O2</code> and the course could have described it. It is not taught because the two available readers did not agree on how to decode it: <code>readelf</code> prints &ldquo;location view pair&rdquo; rows whose begin and end are both zero at offsets where the bytes are <code>0x00</code>, and no third reader was available to break the tie. Rather than pick whichever reading suited the lesson, the entry encoding is left out and the concept that needed it &mdash; location <em>expressions</em>, which is what <code>-O0</code> produces &mdash; is taught and fully cross-checked instead. The same applies to anything else in the research file&rsquo;s &ldquo;still unverified&rdquo; list.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-split">Previous: Split DWARF</a></span>
                <span><a href="/courses/dwarf">Course home</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
