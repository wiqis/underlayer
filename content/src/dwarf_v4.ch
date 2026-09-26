// DWARF Course — Module 5: The Format on Other Inputs
// Concept: DWARF 4 — the version immediately before the version 5 restructure,
// decoded from a real object, and the two things that change when you cross over.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_v4() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("DWARF 4 in Practice — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>DWARF 4 in Practice</h1>
            <div class="lesson-meta">20 min &middot; Module 5: The Format on Other Inputs &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything in Modules 3 and 4 was read out of DWARF 5 files, because that is what the compilers on this machine produce by default. That makes the last four concepts a study of the newest version of the format &mdash; which is a real risk, because <strong>the newest version is not the most common one.</strong></p>
                <p>Debug information outlives the toolchain that made it. Binaries ship with the debug info their build produced, and those builds are frequently older than anything on your machine. A great deal of DWARF 4 in the world was emitted by a GCC whose default has since moved on, and it will still be there, still being read, long after nobody remembers which version produced it.</p>
                <p>So this concept compiles the same source at version 4 and puts it beside the version 5 files from <a href="/courses/dwarf/lessons/dwarf-portability">the portability concept</a>. The result is sharper than a version table: DWARF 4 turns out to differ from DWARF 5 in only two structural ways, and everything else about it is a section that simply is not there.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Build the file, and look at what came out:</p>
                <pre><code>$ gcc -gdwarf-4 -O0 -c t.c -o types_v4.o
$ clang -gdwarf-4 -O0 -c t.c -o types_clang_v4.o</code></pre>
                <p>Two compilers, same source, same version, and the header of the compilation unit is where the first difference shows. Read the first twelve bytes of <code>.debug_info</code> in each, plus the version 5 files for comparison:</p>
                <div class="hex-dump">
                    <pre>gcc   v4:  fe 00 00 00 04 00 00 00 00 00 08 01
gcc   v5:  29 02 00 00 05 00 01 08 00 00 00 00 01 00
clang v4:  e5 00 00 00 04 00 00 00 00 00 08 01
clang v5:  a5 00 00 00 05 00 01 08 00 00 00 00 01 00
</pre>
                </div>
                <p>Now the whole difference is visible in one column. Decode the version 4 header from gcc, field by field, using the offsets you already know:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Bytes</th><th scope="col">Field</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>fe 00 00 00</code></td><td><code>unit_length</code></td><td>254</td></tr>
                        <tr><td><code>04 00</code></td><td><code>version</code></td><td>4</td></tr>
                        <tr><td><code>00 00 00 00</code></td><td><code>debug_abbrev_offset</code></td><td>0 &mdash; at offset <strong>6</strong></td></tr>
                        <tr><td><code>08</code></td><td><code>address_size</code></td><td>8 &mdash; at offset <strong>10</strong></td></tr>
                        <tr><td><code>01</code></td><td>first abbrev code</td><td>the first DIE is at <strong>0xb</strong></td></tr>
                    </tbody>
                </table>
                <p>Compare the field <em>positions</em> with version 5. In DWARF 5, <code>debug_abbrev_offset</code> is at offset <strong>8</strong> and <code>address_size</code> at offset <strong>7</strong>, because <code>unit_type</code> occupies offset 6. In DWARF 4 there is no <code>unit_type</code> at all, so <code>debug_abbrev_offset</code> moves to offset 6 and <code>address_size</code> to offset 10, and the header is <strong>eleven bytes instead of twelve</strong>.</p>
                <p>So the first DIE is at <code>0xb</code> in a version 4 unit and at <code>0xc</code> in a version 5 unit, and that one byte is the entire geometric difference. The <a href="/courses/dwarf/lessons/dwarf-portability">portability concept</a> told you to predict which side of the split version 4 falls on, and to go compile it. This is the answer: it is on the old side, with an eleven-byte header, exactly as predicted.</p>
                <div class="callout callout-warn">
                    <strong>And nothing in the file tells you the header is eleven bytes.</strong> <code>unit_length</code> counts the whole unit <em>including</em> the header, so you cannot derive the header size from it. There is no header-length field. The <em>only</em> thing in the file that says how to parse the header is the <code>version</code> field, which is why a reader that hardcodes 12 or hardcodes 11 is wrong half the time, and why the very first thing a DWARF reader must do is read that field before it computes anything else.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>What the two versions leave out</h3>
                <p>The more consequential difference is not in the header at all. It is in which sections exist:</p>
                <div class="hex-dump">
                    <pre>$ readelf -S -W types_v4.o | grep -oE '\.debug_[a-z_]+'
.debug_abbrev
.debug_aranges
.debug_info
.debug_line
.debug_str

$ readelf -S -W types_v5.o | grep -oE '\.debug_[a-z_]+'
.debug_abbrev  .debug_addr   .debug_aranges  .debug_info
.debug_line    .debug_line_str  .debug_str   .debug_str_offsets
</pre>
                </div>
                <p>Three sections exist in the version 5 build and not in the version 4 build: <code>.debug_addr</code>, <code>.debug_str_offsets</code> and <code>.debug_line_str</code>. And the absence is not an accident of these flags &mdash; those three sections exist to support forms that <strong>do not exist in version 4</strong>. The abbreviation tables show it directly:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Forms in the abbrev table</th><th scope="col">Version 4</th><th scope="col">Version 5</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>DW_FORM_sec_offset</code></td><td>yes</td><td>yes</td></tr>
                        <tr><td><code>DW_FORM_string</code></td><td>yes</td><td>&mdash;</td></tr>
                        <tr><td><code>DW_FORM_strp</code></td><td>yes</td><td>&mdash;</td></tr>
                        <tr><td><code>DW_FORM_strx</code></td><td>&mdash;</td><td>yes</td></tr>
                        <tr><td><code>DW_FORM_addrx</code></td><td>&mdash;</td><td>yes</td></tr>
                    </tbody>
                </table>
                <p>That is the version 4 arrangement in one table. <strong>Strings are inline (<code>DW_FORM_string</code>) or a direct offset into <code>.debug_str</code> (<code>DW_FORM_strp</code>). Addresses are written down (<code>DW_FORM_addr</code>, or <code>DW_FORM_sec_offset</code> for the range-like ones).</strong> There is no indirection, so there is nothing for <code>.debug_str_offsets</code> or <code>.debug_addr</code> to hold.</p>
                <p>And this is the payoff of the portability concept's finding rather than a contradiction of it. That concept measured a 32-bit and a 64-bit build of the same source and found <em>identical</em> unit lengths, because <code>DW_FORM_addrx</code> stores an index so the address width never enters the DIE tree. Version 4 has no such form, so the same trick is unavailable &mdash; and the header shows it. <code>address_size</code> is still 8, the field is still present, and the same source at <code>address_size</code> 4 would produce a version 4 unit of a <em>different</em> length, because the addresses really are in there.</p>
                <h3>The attributes, read by hand</h3>
                <p>The version 4 compile unit, from <code>readelf</code>:</p>
                <pre><code>  Length:        0xfe (32-bit)
  Version:       4
  Abbrev Offset: 0
  Pointer Size:  8
&lt;0&gt;&lt;b&gt;: Abbrev Number: 1 (DW_TAG_compile_unit)
   &lt;c&gt;   DW_AT_producer : (indirect string, offset: 0x12): GNU C23 15.2.0 ... -gdwarf-4 -O0
   &lt;10&gt;   DW_AT_language : 12 (ANSI C99)
   &lt;11&gt;   DW_AT_name     : t.c
   &lt;15&gt;   DW_AT_comp_dir : (indirect string, offset: 0xd2)
   &lt;19&gt;   DW_AT_low_pc  : 0
   &lt;21&gt;   DW_AT_high_pc : 0x89</code></pre>
                <p>Three details in that listing are worth pausing on, and all three are things a version 5 reader gets for free.</p>
                <p><strong>First, the attribute offsets.</strong> They run <code>0xc</code>, <code>0x10</code>, <code>0x11</code>, <code>0x15</code>, <code>0x19</code>, <code>0x21</code> &mdash; and the DIE itself started at <code>0xb</code>. The gap from <code>0xb</code> to <code>0xc</code> is the abbrev code, one byte, and the gap from <code>0x21</code> to the end of the unit is where <code>0x00</code> sits, the end-of-children marker. That is the same structure as version 5 and it is worth being able to walk, because an attribute offset in a reader is not a line number &mdash; it is a byte position in the section.</p>
                <p><strong>Second, <code>DW_AT_high_pc : 0x89</code> next to <code>DW_AT_low_pc : 0</code>. That is not an address range from 0 to 137.</strong> It is <code>DW_FORM_data4</code>, and a <code>high_pc</code> that is <em>not</em> in <code>DW_FORM_addr</code> is a <strong>length relative to <code>low_pc</code></strong>. So the function is 137 bytes long and sits at address zero, because this is a relocatable object. This is the address-versus-length rule from <a href="/courses/dwarf/lessons/dwarf-address-to-line">the address-to-line concept</a>, and it is the single most common way a reader misreports a function's extent &mdash; here it would report a function occupying addresses 0 to 137, which overlaps every other function in the file.</p>
                <p><strong>Third, <code>DW_AT_language : 12 (ANSI C99)</code>, where the version 5 build of the same source says <code>29 (C11)</code>.</strong> That is a compiler-version difference rather than a format one, and it is a good reminder that <code>producer</code> is a first-class field: when a reader reports something surprising, the producer string is the first place to look, because the same source through a different compiler can differ in ways that have nothing to do with the format.</p>
                <h3>What version 4 does not have, stated as a list</h3>
                <p>Pulling the last four modules together, the things a version 4 reader must never encounter and a version 5 reader meets constantly:</p>
                <ul>
                    <li><strong>No <code>unit_type</code>.</strong> There is exactly one kind of unit, and it is a compile unit. Type units and split units did not exist yet &mdash; the next two concepts cover both.</li>
                    <li><strong>No <code>DW_FORM_strx</code>, <code>DW_FORM_addrx</code>, or <code>DW_FORM_rnglistx</code>.</strong> The whole indexed-address machinery, which is what makes <code>.debug_addr</code> and <code>.debug_str_offsets</code> necessary, arrived in version 5.</li>
                    <li><strong>No <code>.debug_line_str</code>, and no <code>DW_FORM_line_strp</code>.</strong> So a file-name string lives in <code>.debug_str</code> like any other string.</li>
                    <li><strong>No <code>.debug_loclists</code> or <code>.debug_rnglists</code>.</strong> A variable with per-address-range locations used <code>.debug_loc</code> and <code>.debug_ranges</code>, which are different sections with different opcodes. The version 5 tables and the <code>DW_LLE</code> / <code>DW_RLE</code> opcode sets simply do not exist here.</li>
                    <li><strong>No split debugging.</strong> No skeleton units, no <code>dwo_id</code>, no <code>DW_AT_GNU_dwo_name</code>.</li>
                </ul>
                <p>And that list is the honest summary of what "version 5" was: not a redesign of the DIE tree, which is essentially unchanged, but a change to <em>how values are referenced</em> &mdash; from writing them down to indexing them &mdash; plus three new sections and a new unit kind to carry the indices.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a reader has to branch on, and the order the branches have to come in. Getting this wrong does not produce an error; it produces a plausible tree, which is why the ordering matters as much as the conditions.</p>
                <div class="formula">
read unit_length
if unit_length == 0xffffffff:
    offset_size = 8
    read 8 more bytes into unit_length
else:
    offset_size = 4

version = read 2 bytes

if version &gt;= 5:
    unit_type   = read 1 byte
    address_size = read 1 byte
    abbrev_offset = read unsigned of offset_size bytes
    if unit_type == DW_UT_type:
        type_signature = read 16 bytes
        type_offset    = read unsigned of offset_size bytes
    if unit_type == DW_UT_split_compile:
        dwo_id = read 8 bytes
    first_die = here
else:
    abbrev_offset = read unsigned of offset_size bytes
    address_size  = read 1 byte
    first_die = here
</div>
                <p>Three things about that order are load-bearing. <strong>The version test comes before the address-size read</strong>, because the two fields swap positions across the version boundary and a reader that reads <code>address_size</code> first gets the wrong byte in both versions. <strong><code>unit_type</code> is only read in version 5 or later</strong>, so a version 4 reader must not consume it &mdash; consuming it would shift every subsequent field by one byte and produce a version 4 unit that decodes into a version 5 unit's worth of nonsense. And <strong>the version 5 extras are keyed on <code>unit_type</code>, not on the version</strong>: a version 5 compile unit has no signature and no <code>dwo_id</code>, and a reader that reads 16 bytes of signature for every version 5 unit will be wrong for most of them.</p>
                <p>Now the failure modes, which are what a version gate actually buys you:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Bug</th><th scope="col">Symptom</th><th scope="col">Why it is silent</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Hardcode a 12-byte header</td><td>Every version 4 unit's first DIE is read one byte late</td><td>The abbrev code is a small integer, so a shifted read still yields a plausible abbrev number</td></tr>
                        <tr><td>Read <code>address_size</code> before branching</td><td>Version 5 units report address size 0 or 8 by accident</td><td>The wrong byte is often a valid size</td></tr>
                        <tr><td>Always read <code>unit_type</code></td><td>Version 4 units decode as a unit type of 0 or a random value</td><td><code>DW_UT_compile</code> is 1, and a shifted read can land on it</td></tr>
                        <tr><td>Assume <code>.debug_str_offsets</code> exists</td><td>Every <code>DW_FORM_strx</code> resolves to garbage</td><td>You read a plausible offset from the wrong section, or from nothing</td></tr>
                    </tbody>
                </table>
                <p>Not one of those produces a diagnostic. Each produces a DIE tree that a debugger will happily walk, with wrong string offsets and wrong addresses, and the result is source lines attached to the wrong functions. This is the argument for the version gate in one table: the cost of the gate is one comparison, and the cost of skipping it is a reader that fails only on the files it was not tested on.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -gdwarf-4 -O0 -c t.c -o v4.o
$ clang -gdwarf-4 -O0 -c t.c -o cv4.o
$ readelf -S -W v4.o | grep -oE '\.debug_[a-z_]+'
$ readelf --debug-dump=abbrev v4.o | grep -oE 'DW_FORM_[a-z0-9_]+' | sort -u</code></pre>
                <ul>
                    <li><strong>Confirm the prediction.</strong> The portability concept told you version 4 would put the first DIE at <code>0xb</code>. Compile it, look, and check. Then do it for version 3 as well, which shares the eleven-byte header &mdash; so the boundary is not between 3 and 4, it is between 4 and 5, and finding that out yourself is worth more than being told.</li>
                    <li><strong>Build the side-by-side form table yourself.</strong> Compile at versions 2, 3, 4 and 5, and for each dump the set of forms actually used in its abbrev table. Four sorted lists side by side is the whole history of the form system in about a minute of work, and it is the single most useful thing to have memorised before reading a specification.</li>
                    <li><strong>Find the <code>high_pc</code> trap in a file where it bites.</strong> In the version 4 object, <code>low_pc</code> is 0 and <code>high_pc</code> is <code>0x89</code>. Write two lines of code that report a function's extent &mdash; one that adds, one that subtracts &mdash; and see which produces a set of functions that do not overlap. Then link the object and check again, because after linking <code>low_pc</code> is real and the answer changes shape.</li>
                    <li><strong>Prove the three missing sections are a consequence, not a choice.</strong> Compile with <code>-gdwarf-4</code> and try to make clang emit <code>.debug_addr</code>. You cannot, because the form it exists to support does not exist. Now try <code>-gdwarf-5</code> and count how many <code>DW_FORM_addrx</code> attributes appear. The section count follows directly from the form count, which is the actual design relationship.</li>
                    <li><strong>Read a version 4 file with a version 5 reader and find the first wrong byte.</strong> Take the decoder shipped with this course, point it at <code>types_v4.o</code>, and find the exact attribute where its output stops matching <code>readelf</code>. Then move the version test to the top of the function and confirm it matches. That is the whole exercise, and it is the most direct demonstration of the gate you will get.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you are handed a compilation unit and told only that its <code>version</code> field reads 4. Its <code>debug_abbrev_offset</code> is 0 and its <code>address_size</code> is 8. Where do those two fields sit, how long is the header, and what is the offset of the first DIE?</p>
                <div class="quiz" id="quiz-dwarf-v4-1">
                    <button class="quiz-option" data-correct="true" data-explain="Version 4 has no unit_type field, so the layout is the older one: unit_length at 0, version at 4, debug_abbrev_offset at 6, address_size at 10, and the first DIE at 0xb. The header is eleven bytes, one shorter than version 5, and the whole difference is the absence of the single unit_type byte. Nothing in the file records the header length, so this is the case where a reader cannot infer its own layout and must be told by the version." onclick="checkQuiz('quiz-dwarf-v4-1', this)"><code>debug_abbrev_offset</code> at offset 6, <code>address_size</code> at offset 10, an eleven-byte header, first DIE at <code>0xb</code>. The absent <code>unit_type</code> byte is the entire difference from version 5</button>
                    <button class="quiz-option" data-correct="false" data-explain="Those are the version 5 positions, and applying them to a version 4 unit reads the wrong bytes. Because unit_type is absent rather than zero, the bytes at offsets 6 and 7 in a version 4 unit are the low half of debug_abbrev_offset, so a reader using the version 5 layout gets an abbrev offset like 0x0000 instead of 0 and a unit type taken from a padding byte." onclick="checkQuiz('quiz-dwarf-v4-1', this)"><code>debug_abbrev_offset</code> at offset 8, <code>address_size</code> at offset 7, a twelve-byte header, first DIE at <code>0xc</code>. The layout is the same as version 5</button>
                    <button class="quiz-option" data-correct="false" data-explain="The header is not a fixed size in DWARF. It is eleven bytes in versions 2 through 4 and twelve from version 5 on, and the file records no header length at all. unit_length counts the header, so you cannot divide it out. This is why the version field has to be read before the layout is decided." onclick="checkQuiz('quiz-dwarf-v4-1', this)"><code>debug_abbrev_offset</code> at offset 4, <code>address_size</code> at offset 8, a nine-byte header, first DIE at <code>0x9</code>. The header is the same in every version, so only the version field differs</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your DWARF reader is in production and is now failing on a customer's binaries &mdash; but only on some of them, and only for functions in files with more than one compilation unit. Everything else is fine. You have no control over the customer's toolchain and cannot ask them to rebuild. Given what this concept established, what is your leading hypothesis, and what is the cheapest thing you can check before you start changing code?</p>
                <div class="quiz" id="quiz-dwarf-v4-2">
                    <button class="quiz-option" data-correct="true" data-explain="The pattern localises the bug before you look at a byte. A failure confined to specific binaries, in specific functions, points at a per-file property rather than shared machinery, and DWARF version is exactly that. The cheapest check costs nothing: run your reader over one failing file and one working file, read the first byte pair of the compilation unit header, and compare the version fields. If the failing file says 4 and the working one says 5, you have your answer in one command, and you know the fix is a version branch rather than a rewrite. Asking for the producer string is the natural second step, because it tells you which compiler and which flags produced the file, which tells you which other version-dependent features might be lurking. The general habit is to let a failure that is confined to a subset of inputs choose the investigation, because the subset is the evidence and it is free." onclick="checkQuiz('quiz-dwarf-v4-2', this)">The failing files are almost certainly DWARF 4, and your reader assumes the version 5 layout. The cheapest check is to read the <code>version</code> field of one failing file and one working file &mdash; two commands &mdash; before touching any code</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real possibility and it is worth ruling out, but it does not fit the evidence. The high_pc trap is a per-attribute interpretation and it would affect every file from that compiler, including single-compilation-unit ones and including the files your reader handles correctly. A failure that skips whole files points at something decided once per file, and the version field is decided once per file." onclick="checkQuiz('quiz-dwarf-v4-2', this)">The customer is using a different compiler, and the <code>DW_AT_high_pc</code> address-versus-length convention differs, so functions are reported with the wrong extents</button>
                    <button class="quiz-option" data-correct="false" data-explain="Worth checking, and it is a different failure than the one described. Unit type does not vary within a single file in a way that would correlate with having several compilation units, and the version 4 versus 5 distinction is precisely the property that does vary between the customer's files and yours. Look at what differs between the working set and the failing set rather than at what varies inside a file." onclick="checkQuiz('quiz-dwarf-v4-2', this)">The failing files contain type units or split units, which your reader does not handle, and they appear in larger projects</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a per-file property is the first suspect for a per-file failure. Version, address size and offset size are the three things a file states about itself, and they are stated once at the top of every section. Reading three integers costs less than any amount of speculation.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the payoff for <a href="/courses/dwarf/lessons/dwarf-versions">the version concept</a>, which listed what each version changed and flagged that the version 5 header breaks a reader. That is now a decoded file rather than a table, and the specific breakage is one byte.</p>
                <p>The missing <code>unit_type</code> is the next concept's subject. A version 4 file has exactly one kind of unit; version 5 has four, and the header field that distinguishes them is the byte this one does not have. <a href="/courses/dwarf/lessons/dwarf-type-units">Type units</a> are the one kind that existed before version 5 in a different section, so that concept starts in version 4 and moves forward.</p>
                <p>And the version 4 arrangement of unwind data &mdash; <code>.eh_frame</code> rather than <code>.debug_frame</code> &mdash; is the subject of the concept after that. The CFI in <a href="/courses/dwarf/lessons/dwarf-frames">the frames concept</a> was read out of <code>.eh_frame</code>, and the section that shares the name with the rest of the debug sections has a different and simpler encoding. Two sections, two formats, one job, and knowing which is which is the difference between a working unwinder and one that reads plausible nonsense.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-type-units">Type Units</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-packages">Previous: Packages</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-type-units">Next: Type Units</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
