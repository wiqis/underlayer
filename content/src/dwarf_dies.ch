// DWARF Course — Module 3: DIEs, Types, Scopes, Locations and Frames
// Concept: the DIE tree, abbreviation codes, and how one .debug_info holds many units.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_dies() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The DIE Tree — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>The DIE Tree</h1>
            <div class="lesson-meta">20 min &middot; Module 3: DIEs, Types and Scopes &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Modules 1 and 2 read the line number program, which answers one question: which source line is this address on. Everything else a debugger needs is in a different section, and that section is not a table. It is a <strong>tree</strong>, compressed so aggressively that the compression is itself the first thing you have to understand.</p>
                <p>The unit of the tree is the <strong>DIE</strong> &mdash; a Debugging Information Entry. Each one is a tag (what kind of thing), a list of attributes (what is known about it), and a flag saying whether it has children. A struct's members, a function's parameters, a variable's type: all of it is DIEs arranged in a tree, and the whole tree is what lets a debugger say <code>g_nest.next-&gt;x</code> and be right.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three ideas, in the order you need them:</p>
                <ol>
                    <li><strong>A DIE is a number plus a list.</strong> In <code>.debug_info</code>, a DIE is a single ULEB128 &mdash; an <em>abbreviation code</em> &mdash; followed by a run of attribute values. The code says which <em>shape</em> the DIE has; the values fill that shape in.</li>
                    <li><strong>The shape lives in <code>.debug_abbrev</code>.</strong> For each code: a tag, a has-children flag, and a list of (attribute, form) pairs. A form says how to read the value &mdash; one byte, four bytes, a ULEB, an offset into a string section.</li>
                    <li><strong>A zero code ends a run of siblings.</strong> A <code>0</code> byte in <code>.debug_info</code> is not a DIE. It is a closing bracket.</li>
                </ol>
                <div class="callout callout-warn">
                    <strong>Why the abbreviation table exists at all.</strong> The reference binary has 54 DIEs. Written out naively, every one of them would repeat the tag and the attribute names &mdash; roughly 40 bytes of pure repetition per DIE. Instead each distinct <em>shape</em> is described once in <code>.debug_abbrev</code>, and the DIE itself becomes just the code plus the values. Two <code>DW_TAG_member</code> DIEs with identical attribute lists both use code 7, and cost one byte each. The design is the reason <code>.debug_info</code> is 0x2e0 bytes for 54 DIEs rather than several kilobytes.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The first DIE of the reference binary, at <code>.debug_info</code> offset 0x0c, decoded field by field. Every value here was produced by a decoder written from the specification and then required to match both <code>readelf</code> and <code>llvm-dwarfdump</code>.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Bytes</th><th scope="col">Attribute</th><th scope="col">Form</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x0c</td><td><code>0b</code></td><td colspan="3">abbreviation code 11</td><td><code>DW_TAG_compile_unit</code>, has children</td></tr>
                        <tr><td>0x0d</td><td><code>63 00 00 00</code></td><td><code>DW_AT_producer</code></td><td><code>strp</code></td><td>offset 0x63 into <code>.debug_str</code></td></tr>
                        <tr><td>0x11</td><td><code>1d</code></td><td><code>DW_AT_language</code></td><td><code>data1</code></td><td>29 = C11</td></tr>
                        <tr><td>0x12</td><td><code>03</code></td><td>attribute <strong>0x90</strong></td><td><code>data1</code></td><td>3 = C</td></tr>
                        <tr><td>0x13</td><td><code>47 16 03 00</code></td><td>attribute <strong>0x91</strong></td><td><code>data4</code></td><td>0x31647 = 202311</td></tr>
                        <tr><td>0x17</td><td><code>00 00 00 00</code></td><td><code>DW_AT_name</code></td><td><code>line_strp</code></td><td>offset 0 &rarr; <code>types.c</code></td></tr>
                        <tr><td>0x1b</td><td><code>08 00 00 00</code></td><td><code>DW_AT_comp_dir</code></td><td><code>line_strp</code></td><td>offset 8 &rarr; the build directory</td></tr>
                        <tr><td>0x1f</td><td><code>49 11 00 00 00 00 00 00</code></td><td><code>DW_AT_low_pc</code></td><td><code>addr</code></td><td>0x1149</td></tr>
                        <tr><td>0x27</td><td><code>80 00 00 00 00 00 00 00</code></td><td><code>DW_AT_high_pc</code></td><td><code>data8</code></td><td><strong>0x80 = 128 bytes</strong></td></tr>
                        <tr><td>0x2f</td><td><code>00 00 00 00</code></td><td><code>DW_AT_stmt_list</code></td><td><code>sec_offset</code></td><td>0 &mdash; the join to <code>.debug_line</code></td></tr>
                        <tr><td>0x33</td><td><code>01</code></td><td colspan="3">next DIE&rsquo;s abbrev code</td><td><code>DW_TAG_base_type</code></td></tr>
                    </tbody>
                </table>
                <p>Two things in that table are worth a second look, because both are traps rather than facts.</p>
                <p><strong>Attributes 0x90 and 0x91 have no agreed name.</strong> The two reference readers disagree about them:</p>
                <div class="formula">
readelf:         DW_AT_language_name      DW_AT_language_version
llvm-dwarfdump:  DW_AT_unknown_90         DW_AT_unknown_91
                </div>
                <p>The numbers and the values agree; only the names differ. These are gcc extensions sitting in the DWARF 5 range with no standard name, so each tool picks a label. <strong>The attribute number is the truth and the name is a convention.</strong> When you write a tool, key off the number.</p>
                <p><strong><code>DW_AT_high_pc</code> is a length here, not an address.</strong> Its form is <code>DW_FORM_data8</code>, which means the value 0x80 is a byte count. The function runs 0x1149 to 0x11c9. A reader that treats 0x80 as an address concludes the function spans from 0x1149 to 0x80, which is nonsense &mdash; and the form is the only thing that tells you. The rule is: if the form is an <em>address</em> form, <code>high_pc</code> is an address; if it is a <em>constant</em> form, it is a length. This is the same trap you met in the line program, in a different attribute.</p>
                <h3>One section, many units</h3>
                <p>The reference binary links two <code>.c</code> files, so <code>.debug_info</code> holds <strong>two</strong> units back to back, each with its own length and its own abbreviation table:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Unit at</th><th scope="col"><code>unit_length</code></th><th scope="col"><code>debug_abbrev_offset</code></th><th scope="col">DIEs</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x0</td><td>0x20b</td><td>0x0</td><td>27</td></tr>
                        <tr><td>0x20f</td><td>0xcd</td><td>0x100</td><td>27</td></tr>
                    </tbody>
                </table>
                <p>A decoder that reads the first unit and stops reports 27 DIEs where <code>readelf</code> reports 54, and raises no error at all. The unit header is self-delimiting, so the fix is to loop until the section is exhausted.</p>
                <h3>The abbreviation table trap</h3>
                <p>Those two units point at two <em>different</em> tables in <code>.debug_abbrev</code>, and the second reuses the codes 1 to 15 for entirely different tags. <code>readelf</code> lists all thirty entries:</p>
                <pre><code>$ readelf --debug-dump=abbrev assets/samples/types_O0 | grep -cE '^   [0-9]+ '
30</code></pre>
                <p>So a table ends at a lone <code>0</code> code, and a decoder must stop there. Collecting every entry into one dictionary keyed by code lets the second table overwrite the first, and the result is the nastiest kind of wrong: the byte walk stays in step, every DIE is still found at the correct offset, every value is still read with the correct form &mdash; and every tag name and attribute list belongs to the wrong table. Nothing crashes. Nothing misaligns. It simply describes a different program.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Reading the tree by hand. The first four DIEs, with the indentation showing the nesting:</p>
                <div class="hex-dump">
                    <pre>&lt;0&gt;&lt;0c&gt;  abbrev 11  DW_TAG_compile_unit        [has children]
  &lt;1&gt;&lt;33&gt;  abbrev 1   DW_TAG_base_type         unsigned char
  &lt;1&gt;&lt;3a&gt;  abbrev 1   DW_TAG_base_type         short unsigned int
  &lt;1&gt;&lt;41&gt;  abbrev 1   DW_TAG_base_type         unsigned int</pre>
                </div>
                <p>And the shape that code 1 has, from <code>.debug_abbrev</code>:</p>
                <pre><code>1  DW_TAG_base_type  [no children]
     DW_AT_byte_size  DW_FORM_data1
     DW_AT_encoding   DW_FORM_data1
     DW_AT_name       DW_FORM_strp
</code></pre>
                <p>Put those together and the walk is mechanical. At 0x33 read one byte: 1. Look up code 1: a <code>DW_TAG_base_type</code> with no children and three attributes. Read three values in the order the table gives &mdash; one byte, one byte, four bytes &mdash; which lands the next DIE at 0x3a. It is byte-for-byte the same shape, so it is code 1 again.</p>
                <p>Now the nesting. A code with the has-children flag set opens a level; the next <code>0</code> byte closes it. <code>struct Nest</code> at 0xb4 looks like this:</p>
                <div class="hex-dump">
                    <pre>&lt;1&gt;&lt;b4&gt;  abbrev 6   DW_TAG_structure_type  Nest  [has children]
  &lt;2&gt;&lt;bf&gt;  abbrev 2   DW_TAG_member  origin
  &lt;2&gt;&lt;cb&gt;  abbrev 2   DW_TAG_member  label
  &lt;2&gt;&lt;d7&gt;  abbrev 2   DW_TAG_member  flags
  &lt;2&gt;&lt;e3&gt;  abbrev 2   DW_TAG_member  next
  &lt;2&gt;&lt;ef&gt;  00                      &lt;- closes the member list
&lt;1&gt;&lt;f0&gt;  abbrev 8   DW_TAG_array_type  [has children]
  &lt;2&gt;&lt;f9&gt;  abbrev 9   DW_TAG_subrange_type
  &lt;2&gt;&lt;ff&gt;  00                      &lt;- closes it</pre>
                </div>
                <p>The <code>&lt;2&gt;</code> prefix is the depth. The zero at 0xef is not a DIE and has no abbreviation code; it is the bracket closing the four members. A decoder that treats a zero as an error stops here, and one that treats it as a DIE desynchronises at the very next byte.</p>
                <p>All 54 DIEs of the reference binary, their depths, offsets, codes and tags, were compared against both readers. Not a single one differs.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -gdwarf-5 -O0 -o shape types.c main.c
$ readelf --debug-dump=info shape | head -30
$ readelf --debug-dump=abbrev shape | head -20</code></pre>
                <p>Then use the decoder that ships with this course, which is written from the specification rather than from a tool:</p>
                <pre><code>$ cd courses/dwarf/assets
$ python3 dwarf_decode.py ../samples/types_O0 --limit 6
$ python3 crosscheck.py ../samples/types_O0
  types_O0   OK   (54 DIEs, 281 attributes, CFI ops agree)
CROSS-CHECK: ALL READERS AGREE</code></pre>
                <p>Three checks worth making on any binary you open:</p>
                <ul>
                    <li><strong>How many abbreviation tables are there?</strong> More than one unit usually means more than one table. <code>readelf --debug-dump=abbrev</code> prints them consecutively with no separator, which is exactly why they get merged by accident.</li>
                    <li><strong>Do the unit lengths add up?</strong> Start at 0, add <code>unit_length</code> plus 4, and you should land on the next unit header. For the reference binary: 0x0 + 0x20b + 4 = 0x20f, which is where the second unit starts.</li>
                    <li><strong>Is the has-children flag consistent with the zeros?</strong> Every <code>[has children]</code> DIE must be followed by a matching <code>0</code> at the same depth. If a depth never closes, the tree is truncated and something upstream ate a byte.</li>
                </ul>
                <p>And check the trap that cost the most time here: compile with <code>-c</code> instead of linking, and compare <code>readelf</code>&rsquo;s output against a hex dump of the same bytes. They will disagree, and <strong>readelf will be right</strong> &mdash; it applied the relocations that the linker would have applied, and the file itself still holds zeros. This is why every byte-level example in this course uses a linked executable.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you are walking the DIE tree, you have just read a DIE at 0xb4 that is <code>DW_TAG_structure_type</code> with the has-children flag set, and the next byte is <code>02</code>. What does the <code>02</code> mean, and where does the next DIE go?</p>
                <div class="quiz" id="quiz-dwarf-dies-1">
                    <button class="quiz-option" data-correct="true" data-explain="Because the structure has children, the reader descends a level before reading the next DIE. That next byte is the abbreviation code for the first child, which in the reference binary is code 2, a DW_TAG_member named origin. The depth prefix in readelf's output changes from &lt;1&gt; to &lt;2&gt; at exactly this point, which is the visible sign that a level was opened." onclick="checkQuiz('quiz-dwarf-dies-1', this)">The <code>02</code> is the abbreviation code of the first <em>child</em>, and the reader has descended one level because the structure said it has children. It is the <code>origin</code> member</button>
                    <button class="quiz-option" data-correct="false" data-explain="A zero is the sibling terminator, not a tag. The byte here is 02, which as an abbreviation code selects a shape; if the structure had no children, or if the children were exhausted, the byte at this position would be 00 instead, and reading it as a DIE would be the bug." onclick="checkQuiz('quiz-dwarf-dies-1', this)">The <code>02</code> is the tag number, so the next DIE is a <code>DW_TAG_member</code> at the same depth as the structure</button>
                    <button class="quiz-option" data-correct="false" data-explain="A structure's members are children of the structure DIE, not siblings, so they are one level deeper. This is what makes the tree a tree: DW_TAG_member only ever appears as a child of a DW_TAG_structure_type, a union, or a class, and that containment is the whole reason a member's offset is meaningful." onclick="checkQuiz('quiz-dwarf-dies-1', this)">The <code>02</code> is a <code>DW_TAG_member</code> at the same depth, because members are siblings of the struct they belong to</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a DWARF reader and it works on every single-unit binary you test it against. On a binary built from two source files it reports half the functions and no error. What is the bug, and what is the general rule your reader needs?</p>
                <div class="quiz" id="quiz-dwarf-dies-2">
                    <button class="quiz-option" data-correct="true" data-explain="The unit header is self-delimiting, so a reader that decodes one unit and returns has silently truncated its output. The failure is invisible because nothing in the first unit is malformed - there is simply less of it than there should be. A reader must loop over units until the section is consumed, and a useful sanity check is that the sum of unit_length plus 4 lands exactly on the next header and eventually on the section end." onclick="checkQuiz('quiz-dwarf-dies-2', this)">It decodes only the first unit. <code>.debug_info</code> holds one self-delimiting unit per compilation, so the reader must loop over units until the section is exhausted &mdash; and the check is that each <code>unit_length</code> plus 4 lands exactly on the next header</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real hazard, and the fix is correct in spirit, but it is not the bug being described. Merging the two tables would mislabel tags and attribute lists while still finding all 54 DIEs at the right offsets. The symptom here is half the functions missing, which is a unit-boundary problem rather than an abbreviation-table problem." onclick="checkQuiz('quiz-dwarf-dies-2', this)">It is using the wrong abbreviation table, because two units means two tables and the reader merged them</button>
                    <button class="quiz-option" data-correct="false" data-explain="Nothing is lost here. The second unit's functions are present in the file, just not in the reader's output. The distinction matters: a bug that drops data can often be detected by a count, whereas a bug that mislabels data while keeping every record cannot be detected that way at all." onclick="checkQuiz('quiz-dwarf-dies-2', this)">The second unit's DIEs genuinely are missing from the file, because gcc only emits one unit per output section</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a container that is self-delimiting must be walked to its end, and the walk must be checked against the container's own size. A parser that stops early is the one class of bug that produces plausible output rather than a crash.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The DIE tree is the same data the <a href="/courses/elf/lessons/symbol-table">ELF symbol table</a> holds, with a great deal more structure. An ELF symbol gives you a name, an offset and a size; a DIE gives you a <em>type</em>, a <em>scope</em>, a <em>source location</em> and a relationship to other DIEs. The <a href="/courses/dwarf/lessons/dwarf-sections">DWARF sections</a> concept explains why <code>.debug_info</code> is the biggest of them, and <a href="/courses/dwarf/lessons/dwarf-versions">the versions concept</a> covers what changes between DWARF 2 and 5 in the unit header you just read.</p>
                <p>The abbreviation table has a direct ancestor in the COFF course: the <a href="/courses/coff/lessons/coff-string-table">COFF string table</a> is the same idea of resolving a small number to a name through a shared pool, and the <a href="/courses/coff/lessons/coff-symbol-table">COFF aux record</a> is a cousin of the attribute list &mdash; both exist so a record can name a shape once and then store only what varies.</p>
                <p>Two concepts build directly on this one. Next, the thing the tree exists to describe: <a href="/courses/dwarf/lessons/dwarf-types">Types and Type Chains</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-versions">Previous: DWARF Versions</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-types">Next: Types and Type Chains</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
