// DWARF Course — Module 2: The Line Number Program
// Concept: Directory and file tables — how a line number becomes a filename.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_file_tables() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Directory and File Tables — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Directory and File Tables</h1>
            <div class="lesson-meta">17 min &middot; Module 2: The Line Number Program &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The line program tells you that address 0x1154 is on line 15. That is not useful on its own &mdash; line 15 <em>of what?</em> A single binary is built from many source files, and the line program only ever refers to them by <em>number</em>.</p>
                <p>The tables that turn those numbers into paths sit in the 56 bytes of header you skipped, and they are the single worst-designed corner of DWARF: two completely different encodings, one per modern version, both still in the wild, neither self-describing enough to save you.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two lists, and one indirection. The line program's rows carry a <em>file number</em>. The file table maps numbers to names. Each name carries a <em>directory number</em>, and the directory table maps numbers to paths. The full path is the directory plus the name.</p>
                <p>That two-step structure is not decoration. It is why <code>shape.c</code> appears twice in our file's table: once for the compile unit itself and once for the function bodies, or in DWARF 5's case because the compiler emitted both a DWARF 4-style entry and a v5-style one. Repeating a 4-byte number is far cheaper than repeating a path.</p>
                <div class="callout callout-warn">
                    <strong>Watch the indexing.</strong> In DWARF 2-4, file number <strong>1</strong> is the <em>first</em> file in the table, so valid numbers run 1..N. In DWARF 5, file number <strong>0</strong> is the first entry, so valid numbers run 0..N-1. A v5 table read with v4 indexing is off by one on every single file &mdash; and because the resulting paths still <em>look</em> plausible, this is the kind of bug that ships.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>DWARF 4 and earlier.</strong> Two NUL-terminated string lists, run together, each ended by an empty string. No counts, no length prefixes. A file entry is the name, then three ULEB128 values: directory index, modification time, and file length &mdash; the last two being a build-system feature for telling two same-named files apart. Modern toolchains write zeros for both.</p>
                <p>Here are the real bytes of <code>shape_v4</code>, where the directory table begins at 0x1c and the file table at 0x40:</p>
                <div class="hex-dump">
                    <pre>00000010: 0001 0101 0100 0000 0100 0001 2f75 7372  ............/usr
00000020: 2f69 6e63 6c75 6465 2f78 3836 5f36 342d  /include/x86_64-
00000030: 6c69 6e75 782d 676e 752f 6269 7473 0000  linux-gnu/bits..
00000040: 7368 6170 652e 6300 0000 0074 7970 6573  shape.c....types
00000050: 2e68 0001 0000 7374 6469 6e74 2d69 6e74  .h....stdint-int</pre>
                </div>
                <p>Read it: byte <code>2f</code> at 0x1c is a literal <code>/</code>, and the string <code>/usr/include/x86_64-linux-gnu/bits</code> runs to the NUL at 0x3e. The second NUL at 0x3f is the empty string that terminates the directory list. Then <code>shape.c\0</code> at 0x40, and three zero bytes at 0x48-0x4a: directory 0, mtime 0, length 0. Then <code>types.h\0</code> at 0x4b and <code>01 00 00</code> at 0x53-0x55: directory <strong>1</strong>, mtime 0, length 0. Then <code>stdint-intn.h\0</code> at 0x56 and <code>01 00 00</code> again. Then a single NUL at 0x67 ends the file list.</p>
                <p>Stop there and check: <strong>0x68</strong> is the line program start this file's header claims (0x0a + <code>header_length</code> 0x5e). The table walk landed on it exactly. That is the same self-check you used for the v5 table, and it is the cheapest bug-catcher in this whole format &mdash; a v4 and a v5 table are walked by completely different code, but both must finish on the same number.</p>
                <p>Readelf's rendering, for comparison &mdash; note it displays these <strong>1-based</strong>:</p>
                <pre><code> The Directory Table (offset 0x1c):
  1	/usr/include/x86_64-linux-gnu/bits

 The File Name Table (offset 0x40):
  Entry	Dir	Time	Size	Name
  1	0	0	0	shape.c
  2	1	0	0	types.h
  3	1	0	0	stdint-intn.h</code></pre>
                <p><strong>DWARF 5.</strong> No string bytes in the line header at all. Instead: a <em>format descriptor</em> saying what each entry contains and how each field is encoded, a <em>count</em>, and then that many entries. The descriptor is the clever part &mdash; it means a future version can add a field (a checksum, a size) without changing the layout.</p>
                <p>Here is the real v5 table, decoded from the bytes at 0x1e onwards:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Bytes</th><th scope="col">Meaning</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x1e</td><td><code>01</code></td><td><code>directory_entry_format_count</code></td><td>1 pair follows</td></tr>
                        <tr><td>0x1f-0x20</td><td><code>01 1f</code></td><td><code>directory_entry_format</code></td><td>content type 1 = <code>DW_LNCT_path</code>, form 0x1f = <code>DW_FORM_line_strp</code></td></tr>
                        <tr><td>0x21</td><td><code>02</code></td><td><code>directories_count</code></td><td>2 (ULEB128)</td></tr>
                        <tr><td>0x22-0x25</td><td><code>00 00 00 00</code></td><td>dir[0] path offset</td><td>0x0</td></tr>
                        <tr><td>0x26-0x29</td><td><code>25 00 00 00</code></td><td>dir[1] path offset</td><td>0x25</td></tr>
                        <tr><td>0x2a</td><td><code>02</code></td><td><code>file_name_entry_format_count</code></td><td>2 pairs follow</td></tr>
                        <tr><td>0x2b-0x2e</td><td><code>01 1f 02 0f</code></td><td><code>file_name_entry_format</code></td><td>(path, <code>line_strp</code>), (directory_index, <code>udata</code>)</td></tr>
                        <tr><td>0x2f</td><td><code>04</code></td><td><code>file_names_count</code></td><td>4 (ULEB128)</td></tr>
                        <tr><td>0x30-0x33</td><td><code>1d 00 00 00</code></td><td>file[0] path offset</td><td>0x1d</td></tr>
                        <tr><td>0x34</td><td><code>00</code></td><td>file[0] directory index</td><td>0</td></tr>
                        <tr><td>0x35-0x38</td><td><code>1d 00 00 00</code></td><td>file[1] path offset</td><td>0x1d</td></tr>
                        <tr><td>0x39</td><td><code>00</code></td><td>file[1] directory index</td><td>0</td></tr>
                        <tr><td>0x3a-0x3d</td><td><code>48 00 00 00</code></td><td>file[2] path offset</td><td>0x48</td></tr>
                        <tr><td>0x3e</td><td><code>01</code></td><td>file[2] directory index</td><td>1</td></tr>
                        <tr><td>0x3f-0x42</td><td><code>50 00 00 00</code></td><td>file[3] path offset</td><td>0x50</td></tr>
                        <tr><td>0x43</td><td><code>01</code></td><td>file[3] directory index</td><td>1</td></tr>
                    </tbody>
                </table>
                <p>Every offset and count in that table was decoded independently and then required to match readelf's directory and file listings. The last entry ends at 0x44 &mdash; which is exactly the program start computed in <a href="/courses/dwarf/lessons/dwarf-line-header">the previous concept</a>. The tables are self-checking: if your file-table walk does not land on the program start, you mis-parsed something.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>None of those v5 offsets is a string. They are indices into <code>.debug_line_str</code>, and here is that section in full &mdash; 0x5e bytes:</p>
                <div class="hex-dump">
                    <pre>00000000: 2f74 6d70 2f6f 7065 6e63 6f64 652f 6477  /tmp/opencode/dw
00000010: 6172 662d 7265 7365 6172 6368 0073 6861  arf-research.sha
00000020: 7065 2e63 002f 7573 722f 696e 636c 7564  pe.c./usr/includ
00000030: 652f 7838 365f 3634 2d6c 696e 7578 2d67  e/x86_64-linux-g
00000040: 6e75 2f62 6974 7300 7479 7065 732e 6800  nu/bits.types.h.
00000050: 7374 6469 6e74 2d69 6e74 6e2e 6800       stdint-intn.h.</pre>
                </div>
                <p>Now resolve the table. <code>DW_FORM_line_strp</code> means "4-byte offset into <code>.debug_line_str</code>, read a NUL-terminated string from there":</p>
                <ul>
                    <li>dir[0] offset 0x0 &rarr; <code>/tmp/opencode/dwarf-research</code></li>
                    <li>dir[1] offset 0x25 &rarr; <code>/usr/include/x86_64-linux-gnu/bits</code></li>
                    <li>file[0] offset 0x1d, dir 0 &rarr; <code>/tmp/opencode/dwarf-research/shape.c</code></li>
                    <li>file[1] offset 0x1d, dir 0 &rarr; the same file again</li>
                    <li>file[2] offset 0x48, dir 1 &rarr; <code>/usr/include/x86_64-linux-gnu/bits/types.h</code></li>
                    <li>file[3] offset 0x50, dir 1 &rarr; <code>/usr/include/x86_64-linux-gnu/bits/stdint-intn.h</code></li>
                </ul>
                <p>That is byte-for-byte what readelf prints, and it accounts for the whole table. Note the payoff of the <code>line_strp</code> indirection: <code>shape.c</code> is stored once at 0x1d and referenced twice. A v4 file would have had to carry the string twice inline, because v4 has no offset form for names in this table at all.</p>
                <p>Why is <code>shape.c</code> listed twice? Because GCC emits a DWARF 4-style entry alongside the v5 entry for compatibility with older consumers that only understand the first slot. File 0 is the legacy slot; file 1 is the v5 one. A reader that respects the version uses the right one and ignores the other.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -gdwarf-5 -O0 -o shape_v5 shape.c
$ gcc -gdwarf-4 -O0 -o shape_v4 shape.c

$ readelf --debug-dump=rawline shape_v5 | sed -n '/Directory Table/,/^$/p'
$ readelf --debug-dump=rawline shape_v4 | sed -n '/Directory Table/,/^$/p'

$ readelf -p .debug_line_str shape_v5
$ objcopy --dump-section .debug_line_str=ls.bin shape_v5 &amp;&amp; xxd ls.bin</code></pre>
                <p>What to look for: the v5 tables report <em>offsets</em> and format descriptors; the v4 tables report <em>literal strings</em>. Then confirm that every v5 offset, when added to the start of <code>.debug_line_str</code>, lands on a string start &mdash; 0x0, 0x1d, 0x25, 0x48 and 0x50 are all visible as NUL boundaries in the hex dump above.</p>
                <p>Finally, the self-check worth building into any parser: after walking the file table, your cursor should sit exactly at the line program start. Here that is 0x44, which is the sum the header already told you to expect.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a line-program row refers to file number 1. In <code>shape_v5</code>, which file is that, and what goes wrong if you answer with file number 1 read using DWARF 4 indexing rules?</p>
                <div class="quiz" id="quiz-dwarf-file-tables-1">
                    <button class="quiz-option" data-correct="true" data-explain="In v5 the first table entry is number 0, so number 1 is the second entry &mdash; which here is also shape.c, so this particular lookup happens to still be right. But the reason it is right is luck, not design: v4 indexing maps 1 to the first entry, and on any real file with more than one source file the two rules disagree about every single name." onclick="checkQuiz('quiz-dwarf-file-tables-1', this)">It is <code>/tmp/opencode/dwarf-research/shape.c</code> &mdash; the second table entry. Using v4 indexing, 1 would mean the <em>first</em> entry, which happens to also be <code>shape.c</code> here, so the answer coincides while the rule is still wrong</button>
                    <button class="quiz-option" data-correct="false" data-explain="File number 0 in v5 is the legacy DWARF 4-style slot, not the first table position. Under v5 indexing the first table entry is number 0, so asking for the first entry means asking for file number 0, not 1." onclick="checkQuiz('quiz-dwarf-file-tables-1', this)">It is the first table entry, <code>shape.c</code>, and nothing goes wrong &mdash; both versions put the compilation unit's own file first</button>
                    <button class="quiz-option" data-correct="false" data-explain="That is the v5 directory index for the types.h entries, not a file number. File numbers index the file table; directory indices index the directory table, and they are independent numbering spaces." onclick="checkQuiz('quiz-dwarf-file-tables-1', this)">It is <code>/usr/include/x86_64-linux-gnu/bits/types.h</code>, because v4 file numbers start at 1 and types.h is the second entry</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your tool walks a v5 file table, reads <code>file_names_count = 4</code>, and loops <code>for(i = 1; i &lt;= count; i++)</code> to build its lookup array. What is wrong, what will a learner see, and what is the one-line fix?</p>
                <div class="quiz" id="quiz-dwarf-file-tables-2">
                    <button class="quiz-option" data-correct="true" data-explain="v5 tables are 0-based, so the entries are numbered 0, 1, 2, 3. A loop from 1 to 4 covers numbers 1, 2, 3, 4 &mdash; it drops the entry numbered 0 (the legacy shape.c slot here) and looks for a nonexistent entry 4. Number 4 is out of range, so the fix is to loop 0 to count-1, or equivalently index the array by file number directly." onclick="checkQuiz('quiz-dwarf-file-tables-2', this)">It is off by one: v5 entries are numbered 0-3, so the loop skips file 0 and looks for a nonexistent file 4. Every file after the first is off by one position, and file 4 fails outright &mdash; the fix is to loop from 0 to <code>count - 1</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="A loop from 1 to count inclusive is exactly right for DWARF 2-4, where the spec numbers files from 1. The bug is that this is a v5 table, where the spec changed the numbering to start at 0. Nothing is wrong with the loop as written in general &mdash; it is wrong for this version." onclick="checkQuiz('quiz-dwarf-file-tables-2', this)">Nothing is wrong &mdash; DWARF has always numbered files from 1, so the loop is correct and file 4 will simply be missing from the output</button>
                    <button class="quiz-option" data-correct="false" data-explain="Off-by-one errors in a lookup table do not misbehave visibly; they resolve to other valid strings. shape.c and stdint-intn.h are both in this table, so a shifted index still yields a filename that exists in the project &mdash; which is precisely why this bug survives code review and ships." onclick="checkQuiz('quiz-dwarf-file-tables-2', this)">The loop reads one entry too many, so it silently picks up the first bytes of the line program as a fifth file entry</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a table's indexing convention differs between versions, carry the convention as part of the version, not as a constant. A v5-only and a v4-only file both "have four files" here; only one of them has a file numbered 4, and neither tells you which.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Both encodings here are the offset-not-pointer idea from <a href="/courses/elf/lessons/relocation-entries">ELF relocations</a> applied to data instead of code: name the thing once, reference it by number. <code>DW_FORM_line_strp</code> is the same shape as <code>DW_FORM_strp</code>, differing only in which string section it indexes &mdash; the split you learned in <a href="/courses/dwarf/lessons/dwarf-sections">The .debug_* Sections</a>.</p>
                <p>Your reader can now get from the header to a filename. The remaining 0x2f bytes of the section are the line program itself, and the next three concepts decode it: first the standard opcodes, then the arithmetic in the special opcodes, then how a debugger actually uses the result.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-standard-opcodes">The Standard Opcodes</a> &mdash; what each of the twelve byte codes does to the line program's registers.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-line-header">Previous: The .debug_line Header</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-standard-opcodes">Next: The Standard Opcodes</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
