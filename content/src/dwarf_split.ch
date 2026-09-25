// DWARF Course — Module 3: DIEs, Types, Scopes, Locations and Frames
// Concept: split DWARF — skeleton units, the .dwo file, and the string-offset base.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_split() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Split DWARF — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Split DWARF</h1>
            <div class="lesson-meta">19 min &middot; Module 3: DIEs, Types, Scopes and Locations &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Debug information is bigger than the program. On a modest C++ project it routinely exceeds the executable several times over, and almost none of it is used during a normal run: you need one function&rsquo;s DIEs to step through it, and you need the rest only when a breakpoint lands somewhere you did not predict.</p>
                <p>Split DWARF is the answer, and it is not a compression scheme &mdash; nothing is packed. It is a <strong>file split</strong>. The information a debugger needs before it can even start, plus the addresses, stays in the object file where the program can be shipped. The bulk goes into a separate file that the developer keeps and the user never sees.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two files, two jobs.</p>
                <table>
                    <thead>
                        <tr><th scope="col">File</th><th scope="col">Contains</th><th scope="col">Shipped?</th></tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>the <code>.o</code> / executable</td>
                            <td>one <strong>skeleton unit</strong> per compilation, a <strong>dwo_id</strong>, the <strong><code>.debug_addr</code></strong> table, the line program</td>
                            <td>yes &mdash; the skeleton is tiny</td>
                        </tr>
                        <tr>
                            <td>the <code>.dwo</code></td>
                            <td>the real DIE tree, its abbreviations, its strings, the string-offset table</td>
                            <td>no &mdash; kept next to the build</td>
                        </tr>
                    </tbody>
                </table>
                <p>The skeleton is not a summary. It is a <strong>stub whose entire content is "the real thing is over there"</strong>, plus the few things that must be known before you can go and get it.</p>
                <div class="callout callout-warn">
                    <strong>The join is one 8-byte identifier, and it is not a name.</strong> The <code>dwo_id</code> is a hash the compiler invents. It exists so a debugger holding an executable can be handed the <code>.dwo</code> for a specific compilation unit without trusting a filename &mdash; and so it can verify it has the right file. Notice what the skeleton does <em>not</em> contain: not one <code>DW_TAG</code> from the real tree. If you dump the skeleton expecting to find function names there, you will conclude the build produced no debug information at all.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Two source files, compiled <code>gcc -gdwarf-5 -O0 -gsplit-dwarf</code>. The result is one executable and one <code>.dwo</code> holding <strong>both</strong> compilations.</p>
                <p>Here is the skeleton unit, decoded:</p>
                <div class="hex-dump">
                    <pre>--- unit at 0x0: unit_length=0x31 version=5
        unit_type=0x04 (DW_UT_skeleton) dwo_id=0x12e9c545cc3ee5a5
        address_size=8 abbrev_offset=0x0
    header ends at 0x14, so the first DIE is at &lt;0&gt;&lt;14&gt;
    1 abbreviation: 1 = DW_TAG_skeleton_unit

&lt;0&gt;&lt;14&gt;  DW_TAG_skeleton_unit
    &lt;15&gt;   DW_AT_low_pc            0x1149
    &lt;1d&gt;   DW_AT_high_pc           0x80
    &lt;25&gt;   DW_AT_stmt_list         0x0
    &lt;29&gt;   DW_AT_dwo_name          types_split-types.dwo
    &lt;2d&gt;   DW_AT_comp_dir          /tmp/.../dwarf3
    &lt;31&gt;   DW_AT_GNU_pubnames      1        (flag_present: no bytes)
    &lt;31&gt;   DW_AT_str_offsets_base  0x8
</pre>
                </div>
                <p>And the second unit, at 0x35, with a different <code>dwo_id</code> and a different abbreviation table:</p>
                <div class="hex-dump">
                    <pre>--- unit at 0x35: unit_length=0x31 version=5
        unit_type=0x04 (DW_UT_skeleton) dwo_id=0x57891407d925f05c
        abbrev_offset=0x15
    first DIE at &lt;0&gt;&lt;49&gt;
</pre>
                </div>
                <p>Points worth noticing, all confirmed against <code>readelf</code> and <code>llvm-dwarfdump</code>:</p>
                <ol>
                    <li><strong>The unit header is longer than a normal compile unit's.</strong> After <code>address_size</code> a skeleton carries 8 bytes of <code>dwo_id</code>, where a <code>DW_UT_type</code> unit would carry a 16-byte type signature and offset. A decoder that reads the header by unit type gets this right; one that assumes a fixed 12-byte DWARF 5 header reads the first DIE 8 bytes early.</li>
                    <li><strong>Two skeletons, two abbreviation tables, one file.</strong> Both skeletons are in the same <code>.debug_info</code>, and the second points at abbreviation offset 0x15 rather than 0. Exactly the situation that makes <a href="/courses/dwarf/lessons/dwarf-dies">the DIE tree concept</a>&rsquo;s multi-table trap dangerous &mdash; and here it is load-bearing, because the abbreviations in the executable are for skeletons and nothing else.</li>
                    <li><strong>The DIE tree is not in this file.</strong> One <code>DW_TAG_skeleton_unit</code> DIE per unit, two in total. All 39 DIEs of the real tree are in the <code>.dwo</code>.</li>
                </ol>
                <h3>What the .dwo actually contains</h3>
                <p>Five sections, and every one has a <code>.dwo</code> suffix so they can coexist with the skeleton's own:</p>
                <div class="formula">
.debug_info.dwo           the real DIE tree        (39 DIEs here)
.debug_abbrev.dwo         its abbreviations
.debug_line.dwo           its line program
.debug_str_offsets.dwo    the index for DW_FORM_strx
.debug_str.dwo            the strings that index names
                </div>
                <p>The <code>.dwo</code>&rsquo;s unit is a different unit type again &mdash; <code>DW_UT_split_compile</code> (5) rather than <code>DW_UT_skeleton</code> (4) &mdash; and it repeats the same <code>dwo_id</code>:</p>
                <pre><code>--- .debug_info.dwo: unit_length=0x181 version=5
        unit_type=0x05 (DW_UT_split_compile) dwo_id=0x12e9c545cc3ee5a5
    first DIE at &lt;0&gt;&lt;14&gt;: DW_TAG_compile_unit</code></pre>
                <p>That repetition is the pairing. A debugger that has the executable walks to a skeleton, reads the <code>dwo_id</code>, opens each candidate <code>.dwo</code>, and looks for a unit with a matching id.</p>
                <h3>The base that is not in the file</h3>
                <p>Inside the <code>.dwo</code>, names are not string offsets. They are <strong>indices</strong>:</p>
                <div class="hex-dump">
                    <pre>&lt;0&gt;&lt;14&gt;  DW_TAG_compile_unit
    DW_AT_producer : GNU C23 15.2.0 ... -gsplit-dwarf ...
                     via str_offsets[16]
    DW_AT_name     : types.c
                     via str_offsets[26]
    DW_AT_comp_dir : /tmp/.../dwarf3
                     via str_offsets[29]</pre>
                </div>
                <p><code>str_offsets[16]</code> is not an offset into <code>.debug_str.dwo</code> &mdash; it is an index into <code>.debug_str_offsets.dwo</code>, and that table is itself addressed from a base. The base is <code>DW_AT_str_offsets_base</code>, which is <strong>0x8</strong>, and it is in the <em>skeleton</em>, not in the <code>.dwo</code>.</p>
                <p>Ignore it, use base 0, and every string shifts by two entries. This is what that looks like:</p>
                <div class="formula">
with base 0:   DW_AT_producer  -&gt;  "unsigned int"        &lt;- wrong
with base 8:   DW_AT_producer  -&gt;  "GNU C23 15.2.0 ..."  &lt;- matches llvm-dwarfdump
                </div>
                <p>It is the worst class of bug: no error, a well-formed string, and the wrong one. A reader that gets this wrong will happily print <code>unsigned int</code> as the compiler that built the program.</p>
                <p>The same problem exists for addresses. <code>.debug_addr</code> in the skeleton file is a table that <code>DW_FORM_addrx</code> indexes, and its base is <code>DW_AT_addr_base</code>, also on the skeleton. The reference build's <code>.debug_addr</code> is 0x38 bytes &mdash; 56 bytes, which is 7 addresses on a 64-bit target.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a debugger does with a split binary, step by step, using the offsets above:</p>
                <ol>
                    <li><strong>Start in the executable.</strong> Read <code>.debug_info</code>, hit a <code>DW_UT_skeleton</code> unit, and note three things: <code>dwo_id = 0x12e9c545cc3ee5a5</code>, <code>DW_AT_dwo_name = types_split-types.dwo</code>, and <code>DW_AT_str_offsets_base = 8</code>.</li>
                    <li><strong>Resolve the name against the compilation directory.</strong> <code>DW_AT_comp_dir</code> plus <code>DW_AT_dwo_name</code> gives an absolute path. This is the one place a skeleton still refers to things by name, which is why the file is found by name and then <em>verified</em> by id.</li>
                    <li><strong>Open the <code>.dwo</code> and find the matching unit.</strong> Scan its units for <code>dwo_id == 0x12e9c545cc3ee5a5</code>. It is there, as <code>DW_UT_split_compile</code>. If the id does not match, the <code>.dwo</code> is stale &mdash; rebuilt from different source &mdash; and its contents cannot be trusted even though the path resolved.</li>
                    <li><strong>Now read the real tree</strong>, using <code>.debug_abbrev.dwo</code> for shapes, and resolve every <code>strx</code> through <code>.debug_str_offsets.dwo</code> <strong>starting at 8</strong>.</li>
                    <li><strong>Read line numbers from the executable</strong>, not the <code>.dwo</code>. <code>DW_AT_stmt_list = 0</code> points into the skeleton&rsquo;s own <code>.debug_line</code>. The <code>.dwo</code> also has a <code>.debug_line.dwo</code>, and the line program is the one thing that stays in both places.</li>
                </ol>
                <div class="callout callout-tip">
                    <strong>What each half is actually for.</strong> The skeleton exists so the debugger can answer the two questions it must answer before anything else: <em>which addresses have debug information</em> (from <code>low_pc</code>/<code>high_pc</code> and <code>.debug_aranges</code>) and <em>where is the rest</em> (from <code>dwo_name</code> and <code>dwo_id</code>). It also keeps the line program, because stepping one line must not require opening a second file. Everything expensive &mdash; the 39-DIE tree, its types, its strings &mdash; is in the <code>.dwo</code> and is only ever read for the unit you are actually stopped in.
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -gdwarf-5 -O0 -gsplit-dwarf -o shape types.c main.c
$ ls -la shape types_split.dwo
$ readelf --debug-dump=info shape            # skeletons only
$ readelf --debug-dump=info types_split.dwo  # the real tree
$ readelf -S -W shape | grep debug</code></pre>
                <p>Five things to try, in order of how much they teach:</p>
                <ul>
                    <li><strong>Compare the two dumps.</strong> <code>readelf --debug-dump=info</code> on the executable prints 56 DIEs even though the file contains only 2, because readelf follows <code>DW_AT_dwo_name</code> and merges the <code>.dwo</code> in. On the <code>.dwo</code> alone it prints 39. Three numbers, three files, and it is worth being able to explain each.</li>
                    <li><strong>Look for the base.</strong> <code>readelf --debug-dump=info types_split.dwo</code> resolves names without complaining, because readelf read the base from the skeleton. Read the <code>.dwo</code> with no skeleton available and a naive index of 0 gives you <code>unsigned int</code> as the producer.</li>
                    <li><strong>Break the pairing.</strong> Edit one character in the source, recompile only the <code>.dwo</code> (or recompile the other file), and compare the ids. A stale <code>.dwo</code> has a different id from the executable that points at it, and that mismatch &mdash; not the filename &mdash; is what tells you the debug info does not match the binary.</li>
                    <li><strong>Measure the win.</strong> <code>ls -la</code> on both. The skeleton is a few hundred bytes; the <code>.dwo</code> holds the tree. Then build without <code>-gsplit-dwarf</code> and see the difference in the executable, which is where the bulk would otherwise live.</li>
                    <li><strong>Check what stays behind.</strong> <code>.debug_addr</code>, <code>.debug_line</code> and the <code>aranges</code> and <code>pubnames</code> indexes all remain in the executable. Split DWARF moves the tree, not the indexes &mdash; which is exactly what the <a href="/courses/dwarf/lessons/dwarf-lookup">next concept</a> is about.</li>
                </ul>
                <p>And the check for your own reader: after resolving a <code>strx</code>, confirm the string looks like a string for that attribute. A <code>DW_AT_producer</code> that comes back as a C type name is the signature of a missing <code>str_offsets_base</code>, and it is worth asserting on, because nothing else will tell you.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you are decoding <code>.debug_info.dwo</code> on its own, with no skeleton file to hand, and <code>DW_AT_producer</code> comes back as <code>unsigned int</code> instead of the compiler version. What is wrong, and where does the value you need actually live?</p>
                <div class="quiz" id="quiz-dwarf-split-1">
                    <button class="quiz-option" data-correct="true" data-explain="DW_FORM_strx is an index into .debug_str_offsets.dwo, and that table is addressed from a base recorded as DW_AT_str_offsets_base on the skeleton unit - value 8 here. Using base 0 shifts every lookup by two entries, so a valid string comes back as a different valid string. The base is deliberately not duplicated in the .dwo, which is why a reader with only the .dwo cannot get this right on its own." onclick="checkQuiz('quiz-dwarf-split-1', this)">The string indirection is indexed from <code>DW_AT_str_offsets_base</code>, which is <strong>0x8</strong> and lives on the <em>skeleton</em> unit, not in the <code>.dwo</code>. With base 0 every lookup is off by two entries, and a wrong-but-valid string comes back</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real and important property, but it is not the cause of the wrong string. The .dwo does contain a valid .debug_str.dwo, and the strings themselves are correct - it is the index into the offset table that is wrong, because the base was not applied. Saying the strings are missing describes a different failure with a different symptom." onclick="checkQuiz('quiz-dwarf-split-1', this)">The <code>.dwo</code> does not contain the strings at all, so they have to be read from the executable&rsquo;s own <code>.debug_str</code>, which is why the producer string is wrong</button>
                    <button class="quiz-option" data-correct="false" data-explain="The strings are stored once in .debug_str.dwo and referenced by index, which is the compact representation the whole mechanism exists for. Copying them into the skeleton would defeat the point, and the id is there for a different purpose: verifying that a .dwo matches the executable that names it." onclick="checkQuiz('quiz-dwarf-split-1', this)">The <code>dwo_id</code> is the missing piece, because it identifies which string table to use. Without it the reader cannot tell the two compilations&rsquo; tables apart</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A build system starts shipping <code>-gsplit-dwarf</code> builds. Stepping works; hovering for types does not &mdash; the debugger reports an unknown type for every variable, and the log says it could not find the <code>.dwo</code> for one compilation unit. Everything else is fine. What is the most likely cause, and what is the check that distinguishes it from a genuinely stale <code>.dwo</code>?</p>
                <div class="quiz" id="quiz-dwarf-split-2">
                    <button class="quiz-option" data-correct="true" data-explain="The skeleton is what the debugger searches, and its DW_AT_comp_dir plus DW_AT_dwo_name is a path that only resolves if the debug info was kept in the same relative place the compiler recorded. When build systems relocate build trees, strip paths, or package artifacts without the .dwo directory, the skeleton still names the path it was compiled with. Confirm it by reading DW_AT_comp_dir and DW_AT_dwo_name out of the skeleton and checking whether that path still exists." onclick="checkQuiz('quiz-dwarf-split-2', this)">The skeleton records an <strong>absolute path</strong> &mdash; <code>DW_AT_comp_dir</code> plus <code>DW_AT_dwo_name</code> &mdash; and a relocated or stripped build tree means that path no longer resolves. Check the recorded path first, before suspecting staleness</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a genuine and more serious failure mode, and it is worth checking - but its symptom is that the wrong debug information is found, producing types and line numbers that belong to a different build. Here nothing was found at all for one unit, which is a lookup failure rather than a correctness failure." onclick="checkQuiz('quiz-dwarf-split-2', this)">The <code>.dwo</code> is from a previous build, so the <code>dwo_id</code> in the skeleton does not match the one in the file. Confirm it by comparing the two 8-byte ids</button>
                    <button class="quiz-option" data-correct="false" data-explain="Readelf follows DW_AT_dwo_name automatically and merges the tree, which is why its output looks complete. A real debugger generally does the same, and a debugger that skipped the .dwo would report no line information either - so since stepping works, the tool is demonstrably finding and reading the .dwo." onclick="checkQuiz('quiz-dwarf-split-2', this)">The debugger is not following <code>DW_AT_dwo_name</code> at all, and is only reading the skeleton, which contains no type information by design. Confirm it by checking whether the debugger was built with .dwo support</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a system is split into a stub and a payload, the stub has to record enough to <em>find</em> the payload, and that means it records a location. Location is the part that breaks &mdash; not the content, not the identifier, and not the format.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Split DWARF is a file-level version of a pattern the COFF course already covers: <a href="/courses/coff/lessons/coff-comdat">COMDAT</a> keeps one authoritative copy of something that would otherwise be emitted many times, and the linker discards the duplicates. Here the duplication is at whole-file granularity and the identifier is a hash instead of a name &mdash; because the two compilations must agree on it without ever meeting.</p>
                <p>The <a href="/courses/coff/lessons/coff-archives">COFF archive container</a> is the other half of this idea from the other direction: an archive is a file of objects with a symbol index, so a linker can pull in only the members it needs. Split DWARF splits one object into two files along a different seam &mdash; what a program needs to run versus what a developer needs to debug it &mdash; and the seam is invisible in the file format.</p>
                <p>What the skeleton deliberately keeps is the subject of the last concept: the indexes that let a debugger answer &ldquo;which unit covers this address&rdquo; and &ldquo;what is the name of that DIE&rdquo; without reading the whole tree.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-lookup">Finding Things Without Reading Everything</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-frames">Previous: Call Frame Information</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-lookup">Next: Finding Things Without Reading Everything</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
