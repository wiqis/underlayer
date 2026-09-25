// DWARF Course — Module 1: Why Debug Info Exists
// Concept: DWARF 2, 3, 4 and 5 — what changed, and the two layouts that break readers.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_versions() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("DWARF 2, 3, 4 and 5 — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>DWARF 2, 3, 4 and 5</h1>
            <div class="lesson-meta">18 min &middot; Module 1: Why Debug Info Exists &middot; Versioning</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You are about to write a parser. The <code>version</code> field is a 2-byte number at a known offset, and it is the only thing standing between you and a program that reads a v4 file as if it were v5 and produces confident nonsense &mdash; addresses in the wrong place, strings from the middle of other strings, no error anywhere.</p>
                <p>DWARF has changed four times. Two of those changes altered the <em>byte layout</em> of headers that already existed, which is the dangerous kind of change: no new section appears to warn you, the file still looks structurally valid, and only the offsets move.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three rules cover every version difference you will meet:</p>
                <ol>
                    <li><strong>Version gates the layout.</strong> Every offset after the version field is version-relative. Check the version first, before trusting anything else.</li>
                    <li><strong>New sections are safe; moved fields are not.</strong> A parser that ignores a section it does not understand still works. A parser that mis-locates a field does not.</li>
                    <li><strong>The newest version is not always the one in your file.</strong> Toolchains default differently, and build systems pin flags. Always read the version; never assume it.</li>
                </ol>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Same <code>shape.c</code>, same <code>-O0</code>, four versions. The line-number header of each, from <code>readelf --debug-dump=rawline</code>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">DWARF 4</th><th scope="col">DWARF 5</th><th scope="col">Moved?</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>unit_length</code></td><td>0x93 (147)</td><td>0x6f (111)</td><td>no</td></tr>
                        <tr><td><code>version</code></td><td>4</td><td>5</td><td>no</td></tr>
                        <tr><td><code>address_size</code></td><td><strong>absent</strong></td><td>present at 0x06</td><td><strong>added</strong></td></tr>
                        <tr><td><code>segment_selector_size</code></td><td><strong>absent</strong></td><td>present at 0x07</td><td><strong>added</strong></td></tr>
                        <tr><td><code>header_length</code></td><td>0x5e (94) at 0x06</td><td>0x38 (56) at 0x08</td><td><strong>moved</strong></td></tr>
                        <tr><td>fixed prologue size</td><td>10 bytes</td><td>12 bytes</td><td><strong>changed</strong></td></tr>
                        <tr><td>line program starts at</td><td>0x0a + 0x5e = <strong>0x68</strong></td><td>0x0c + 0x38 = <strong>0x44</strong></td><td>derived</td></tr>
                        <tr><td>directory table</td><td>NUL-terminated strings</td><td>counted, explicit form</td><td><strong>replaced</strong></td></tr>
                        <tr><td>file table</td><td>name + 3 ULEBs</td><td>counted, explicit form</td><td><strong>replaced</strong></td></tr>
                        <tr><td><code>line_base</code> / <code>line_range</code> / <code>opcode_base</code></td><td>-5 / 14 / 13</td><td>-5 / 14 / 13</td><td>no &mdash; identical</td></tr>
                    </tbody>
                </table>
                <p>The last row is worth pausing on. <strong>The arithmetic that decodes the line program is byte-identical between v4 and v5.</strong> All of the churn is in the header's front matter and in how paths are stored. So a v5 reader that gets the special-opcode maths right but the header wrong will still fail &mdash; and vice versa. The two halves of this course are independent skills.</p>
                <p>The <code>.debug_info</code> compilation-unit header changed the same way:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">DWARF 4</th><th scope="col">DWARF 5</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>unit_length</code></td><td>0x10e (270)</td><td>0x10c (268)</td></tr>
                        <tr><td><code>version</code></td><td>4</td><td>5</td></tr>
                        <tr><td><code>unit_type</code></td><td><strong>absent</strong></td><td>present at 0x06</td></tr>
                        <tr><td><code>address_size</code></td><td>8</td><td>8</td></tr>
                        <tr><td><code>debug_abbrev_offset</code></td><td>0</td><td>0</td></tr>
                        <tr><td>first DIE begins at</td><td><strong>0x0b</strong></td><td><strong>0x0c</strong></td></tr>
                    </tbody>
                </table>
                <p>One extra byte, and every DIE in the section moves. <code>readelf</code> prints those positions as <code>&lt;0&gt;&lt;b&gt;</code> and <code>&lt;0&gt;&lt;c&gt;</code>.</p>
                <p>DWARF 5 also added attributes that did not exist before: <code>DW_AT_language_name</code> and <code>DW_AT_language_version</code>, both present in our compile unit (<code>3</code> = C, <code>202311</code>). And a whole new form, <code>DW_FORM_line_strp</code>, which resolves against <code>.debug_line_str</code> instead of <code>.debug_str</code>.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Two headers, side by side, from the same source file. Read the first sixteen bytes of each.</p>
                <p><strong>DWARF 4</strong> (<code>-gdwarf-4</code>):</p>
                <div class="hex-dump">
                    <pre>00000000: 9300 0000 0400 5e00 0000 0101 01fb 0e0d  ......^.........
00000010: 0001 0101 0100 0000 0100 0001 2f75 7372  ............/usr</pre>
                </div>
                <p><strong>DWARF 5</strong> (<code>-gdwarf-5</code>):</p>
                <div class="hex-dump">
                    <pre>00000000: 6f00 0000 0500 0800 3800 0000 0101 01fb  o.......8.......
00000010: 0e0d 0001 0101 0100 0000 0100 0001 0101  ................</pre>
                </div>
                <p>Look at byte <strong>0x06</strong>. In the v4 line it is <code>5e</code>, the low byte of <code>header_length = 94</code>. In the v5 line it is <code>08</code>, which is <code>address_size = 8</code> &mdash; a completely different field, at the same offset. Everything after it shifts with it.</p>
                <p><strong>A v5 reader on a v4 file.</strong> It reads <code>address_size = 0x5e = 94</code>, then <code>segment_selector_size = 0</code>, then takes four bytes at 0x08 &mdash; which in a v4 file are <code>00 00 01 01</code> &mdash; as <code>header_length = 16,842,752</code>. Its computed program start is 0x101000c, in a section that is only 0x97 bytes long. The very first thing it reads is past the end of the file.</p>
                <p><strong>A v4 reader on a v5 file.</strong> It reads four bytes at 0x06 &mdash; in a v5 file those are <code>08 00 38 00</code> &mdash; giving <code>header_length = 3,670,024</code>, and computes a program start of 0x380012 in a 0x73-byte section. Again: immediately past the end.</p>
                <p>Notice the failure shape. In both directions the parser does not produce wrong <em>answers</em> at first &mdash; it produces an offset that is obviously insane. That is the good case, and it is why validating the computed offsets against the section size is the single most useful check you can put in a DWARF parser. The genuinely dangerous case is a layout change that shifts an offset by a <em>small</em> amount, keeping every computed value inside the section. That is what the counted-tables change in v5 does, and it is the subject of the next concept.</p>
                <p>This is also why the two tables look so different further in. In v4 the directory table is at offset 0x1c and is a bare run of NUL-terminated strings &mdash; the literal bytes <code>/usr</code> at 0x1f, as you can see above. In v5 there is no string data in the line header at all; every name is a 4-byte offset into <code>.debug_line_str</code>, plus a format descriptor saying how to interpret it.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <p>Build all four versions and confirm the toolchain really does produce them:</p>
                <pre><code>$ for v in 2 3 4 5; do gcc -gdwarf-$v -O0 -o shape_v$v shape.c; done
$ for v in 2 3 4 5; do echo "--- v$v ---"; readelf --debug-dump=rawline shape_v$v | head -8; done</code></pre>
                <p>Now break a file and see the consumer's real complaint. Set the <code>.debug_info</code> version to 9:</p>
                <pre><code>$ readelf --debug-dump=info broken2
readelf: Warning: CU at offset 0 contains corrupt or unsupported version number: 9.</code></pre>
                <p>And set the <code>.debug_line</code> <code>unit_length</code> to something larger than the section:</p>
                <pre><code>$ readelf --debug-dump=rawline broken1
readelf: Warning: The length field (0xfff0) in the debug_line header is wrong - the section is too small</code></pre>
                <p>What to look for: readelf stops at the version gate and decodes nothing further. That is the correct behaviour, and it is the behaviour your own parser needs. When it printed a version warning it had already done the right thing; when it printed a length warning it had trusted <code>unit_length</code> before checking it against the section size &mdash; which is itself a bug worth knowing about.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a v4 reader consumes a v5 file. At offset 0x06 the v5 file has <code>08</code> and the v4 reader expects the low byte of <code>header_length</code>. What wrong value does it compute, and where does its first incorrect byte come from?</p>
                <div class="quiz" id="quiz-dwarf-versions-1">
                    <button class="quiz-option" data-correct="true" data-explain="v5 bytes 0x06-0x09 are 08 00 38 00, so a v4 reader computes 0x380008 = 3,670,024 and a program start of 0x380012, in a section of only 0x73 bytes. The root cause is the single added address_size/segment_selector_size pair in v5, which pushes header_length two bytes later and misaligns everything after it." onclick="checkQuiz('quiz-dwarf-versions-1', this)">It reads <code>header_length = 3,670,024</code> and starts the line program at 0x380012, far past the end of a 0x73-byte section &mdash; its first wrong byte comes from v5 inserting two extra header bytes</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is not a v4-shaped answer. A v4 reader takes four bytes at 0x06, and in a v5 file those are 08 00 38 00, giving 3,670,024. (16,842,752 is the value a v5 reader computes from a v4 file, where it reads header_length at 0x08 instead.)" onclick="checkQuiz('quiz-dwarf-versions-1', this)">It reads <code>header_length = 257</code> and starts the program at 0x10d, past the end of the section</button>
                    <button class="quiz-option" data-correct="false" data-explain="94 is the address_size a v5 reader wrongly takes from a v4 file at 0x06, not what a v4 reader sees in a v5 file. A v4 reader never looks at address_size at all, because that field does not exist in the layout it implements." onclick="checkQuiz('quiz-dwarf-versions-1', this)">It reads <code>address_size = 94</code> and rejects the file, because 94 is not a valid pointer size</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your tool must read binaries from four toolchains: a v2-era cross compiler, a v4 GCC, a v5 GCC, and a v5 Clang whose <code>unit_type</code> is not <code>DW_UT_compile</code>. You may not assume the version, and you may not hard-code one layout. What is the minimum correct order of operations, and what must you do about the Clang unit type?</p>
                <div class="quiz" id="quiz-dwarf-versions-2">
                    <button class="quiz-option" data-correct="true" data-explain="Version is the only field whose position is fixed across all four versions, so it is the one thing safe to read first. In v5 it also selects the layout of the two header bytes that follow, which is what decides whether unit_type is present at all. Then unit_type tells you whether you are reading a compile unit, a type unit, or something else &mdash; all of which have different DIE layouts and must not be parsed as one." onclick="checkQuiz('quiz-dwarf-versions-2', this)">Read <code>version</code> first and dispatch on it, validate <code>unit_length</code> against the section size, then read <code>unit_type</code> in v5 and dispatch per unit type &mdash; a type unit has a completely different DIE layout from a compile unit</button>
                    <button class="quiz-option" data-correct="false" data-explain="Reading section flags cannot identify a unit type, and nothing in the ELF section header carries the DWARF version. The version is the field whose offset is stable across all four layouts, which is exactly what makes it safe to read first." onclick="checkQuiz('quiz-dwarf-versions-2', this)">Read the section flags from the ELF header first, then dispatch &mdash; the flags tell you the version without parsing the unit at all</button>
                    <button class="quiz-option" data-correct="false" data-explain="You cannot skip the version: it is what tells you whether unit_type exists and whether header_length sits at 0x06 or 0x08. Validating unit_length against the section size is necessary, but it is a corruption check, not a version check &mdash; a perfectly intact v4 file would still be parsed wrongly." onclick="checkQuiz('quiz-dwarf-versions-2', this)">Validate <code>unit_length</code> against the section size, then assume v5 because it is the only layout with a counted file table</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: version is the one offset that is stable across every version of a format. Make it your first read and your first branch.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The <code>unit_length</code> field is the same self-describing length you met in the <a href="/courses/elf/lessons/elf-header-fields">ELF header</a>, and the "validate the length against the section size before trusting it" habit is the same one the ELF section header table demands.</p>
                <p>You now know which version your file is and how to tell. Module 2 opens the section that matters most and takes it apart byte by byte, starting with the header you have just learned to distrust.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-line-header">The .debug_line Header</a> &mdash; all fourteen fixed fields of the v5 header, decoded from the real bytes of <code>shape_v5</code>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-sections">Previous: The .debug_* Sections</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-line-header">Next: The .debug_line Header</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
