// DWARF Course — Module 4: Location and Range Lists, Portability, and Packages
// Concept: the same source compiled four ways — 32-bit, 64-bit, ARM, and three
// DWARF versions — to find which parts of the format actually vary.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_portability() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Same Source, Different Target — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Same Source, Different Target</h1>
            <div class="lesson-meta">21 min &middot; Module 4: Location Lists, Portability and Packages &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything so far in this course has been one machine: 64-bit x86, GCC, DWARF 5. Every layout, every offset width, every assumption about what a pointer costs &mdash; verified against files on this disk, and therefore only ever evidence for one configuration.</p>
                <p>A format is not portable because its <em>specification</em> allows for the variation. It is portable when a reader written against one configuration survives contact with another. Those are different claims, and the only way to have the second one is to actually produce the other configurations and diff them.</p>
                <p>So this concept does the experiment: the same C file compiled four ways, with the debug sections read out of the resulting object files. The result is a much sharper answer to "what varies in DWARF" than any amount of reading the specification, because most of what people expect to vary does not vary at all, and one thing that does vary is easy to miss entirely.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three things in this format are not fixed, and each is fixed <em>in a different place</em>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">What varies</th><th scope="col">Declared by</th><th scope="col">Widens when</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>The version</td><td><code>version</code> in the section header</td><td>You change <code>-gdwarf-</code></td></tr>
                        <tr><td>The address size</td><td><code>address_size</code> in the section header</td><td>You change the target</td></tr>
                        <tr><td>The offset size</td><td><code>format</code>: <code>DWARF32</code> or <code>DWARF64</code></td><td>The file exceeds 4 GB of debug info &mdash; not a target property at all</td></tr>
                    </tbody>
                </table>
                <p>Note the third row. Address size, version and offset size are usually conflated because they are all "how wide are the numbers". But they are not the same kind of decision. Address size is a property of the <em>machine</em>. Version is a property of the <em>producer's flag</em>. Offset size is a property of the <em>file's size</em>, and a 32-bit binary can have <code>DWARF64</code> debug info if it carries more than four gigabytes of it.</p>
                <p>That is the first portability lesson and it is purely conceptual: a reader that picks its field widths from the target architecture is wrong even though it looks right, because the format does not tie the two together.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>One file, four builds. The first three are the same source with different <code>clang</code> targets, so the debug information is the compiler's answer to the same program on different hardware:</p>
                <div class="hex-dump">
                    <pre>$ clang --target=i386-linux-gnu   -gdwarf-5 -c t.c -o types_i386.o
$ clang --target=aarch64-linux-gnu -gdwarf-5 -c t.c -o types_aarch64.o
$ gcc -gdwarf-2 -O0 -c t.c -o types_v2.o
$ gcc -gdwarf-3 -O0 -c t.c -o types_v3.o
</pre>
                </div>
                <p>Read the first twelve bytes of <code>.debug_info</code> in each and decode the header by hand:</p>
                <table>
                    <thead>
                        <tr><th scope="col">File</th><th scope="col">Header bytes</th><th scope="col">Version</th><th scope="col">Address size</th><th scope="col">First DIE</th><th scope="col">Unit length</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>types_v2.o</code></td><td><code>11 01 00 00 02 00 00 00 00 00 08 01</code></td><td>2</td><td>8</td><td><code>0xb</code></td><td>273</td></tr>
                        <tr><td><code>types_v3.o</code></td><td><code>07 01 00 00 03 00 00 00 00 00 08 01</code></td><td>3</td><td>8</td><td><code>0xb</code></td><td>263</td></tr>
                        <tr><td><code>types_i386.o</code></td><td><code>a5 00 00 00 05 00 01 04 00 00 00 00 01 00</code></td><td>5</td><td><strong>4</strong></td><td><code>0xc</code></td><td>165</td></tr>
                        <tr><td><code>types_aarch64.o</code></td><td><code>a5 00 00 00 05 00 01 08 00 00 00 00 01 00</code></td><td>5</td><td>8</td><td><code>0xc</code></td><td>165</td></tr>
                    </tbody>
                </table>
                <p>Decode the 32-bit one byte by byte, because it is the interesting case:</p>
                <div class="hex-dump">
                    <pre>a5 00 00 00   unit_length = 165
05 00         version = 5
01            unit_type = DW_UT_compile
04            address_size = 4     &lt;-- 32-bit target: half the pointer
00 00 00 00   debug_abbrev_offset = 0
01 00         the first DIE: abbrev code 1, then 00 = end of its children
</pre>
                </div>
                <p>Now the finding that makes this concept worth reading. <strong><code>types_i386.o</code> and <code>types_aarch64.o</code> both have <code>unit_length = 165</code> &mdash; identical.</strong> One is a 32-bit target and one is 64-bit. Every address in both is half the width of the other's. And yet the compilation unit occupies exactly the same number of bytes.</p>
                <p>The reason is the form. Look at what the reader reports for a low address attribute in the 32-bit build:</p>
                <pre><code>$ readelf --debug-dump=info types_i386.o | grep low_pc
  &lt;1a&gt;  DW_AT_low_pc : (index: 0): 0
  &lt;24&gt;  DW_AT_low_pc : (index: 0): 0</code></pre>
                <p>The value is a <strong>small integer index</strong>, not an address. It names a slot in the <code>.debug_addr</code> section, and the address itself lives over there where its width is decided. Since the index is a <code>UDATA</code> and both files have small indices, the slots in the DIEs are the same size in both &mdash; so the whole unit is the same size.</p>
                <div class="callout">
                    <strong>What this buys, and what it costs.</strong> Indexing addresses is why <code>DW_FORM_addrx</code> exists, and it is not a micro-optimisation. It is the reason the same debug info can describe a 32-bit build and a 64-bit build at all, and the reason a producer does not have to rewrite every address when the target width changes. The cost is indirection: a reader cannot answer "what address is this DIE at" from the DIE alone, and a producer that emits <code>DW_FORM_addr</code> inline instead &mdash; as older producers do &mdash; will produce a unit whose length <em>does</em> change with the address size. If you compare the unit lengths of two files and they differ, that is a signal about forms, not about the target.
                </div>
                <h3>Version, and the header that grows by one byte</h3>
                <p>DWARF 2 and 3 share a header layout; DWARF 5 inserts a field. Here is the whole difference, from the first two rows of the table:</p>
                <div class="hex-dump">
                    <pre>DWARF 2 and 3, 11 bytes:            DWARF 5, 12 bytes:
  unit_length        4 bytes           unit_length        4 bytes
  version            2 bytes           version            2 bytes
  debug_abbrev_offset 4 bytes          unit_type         1 byte   &lt;-- new
  address_size       1 byte            address_size       1 byte
                                       debug_abbrev_offset 4 bytes
</pre>
                </div>
                <p>Consequence: <code>DW_AT_low_pc</code>'s companion, the first DIE, sits at offset <code>0xb</code> in a version 2 or 3 unit and at <code>0xc</code> in a version 5 unit. One byte. And <strong>that one byte is not signalled by anything except the version</strong> &mdash; there is no length field for the header, and the unit length counts the whole unit including the header, so you cannot infer the header size from it. A reader that hardcodes 11 is wrong on every modern file; a reader that hardcodes 12 is wrong on every file older than 2017. The only correct thing is to branch on <code>version</code>.</p>
                <p>And the version changes something structural as well. <code>DW_FORM_line_strp</code> &mdash; an offset into a <code>.debug_line_str</code> section &mdash; appears only in the version 5 build. Versions 2 and 3 have no <code>.debug_line_str</code> section at all:</p>
                <div class="hex-dump">
                    <pre>$ readelf -S -W types_i386.o | grep -c debug_line_str   ->  1
$ readelf -S -W types_v2.o    | grep -c debug_line_str   ->  0
$ readelf -S -W types_v3.o    | grep -c debug_line_str   ->  0
</pre>
                </div>
                <p>So a reader written for version 5 can encounter a form whose target section does not exist, purely because it was handed an older file. A reader that assumes the section is there, because it has always been there, gets a wrong answer rather than a failure.</p>
                <h3>Version 2 versus version 3, and the thing that did not change</h3>
                <p>Both unit lengths are reported, and they are not equal: 273 for version 2, 263 for version 3. Ten bytes of difference in the debug information, from a version bump that changed no header size and no field width. That difference is in the <em>content</em> &mdash; different attribute sets, different types, different DIE counts &mdash; and it is a useful reminder that "portable" is not the same as "identical".</p>
                <p>What is worth noting is what did <em>not</em> change: the address size stayed 8, the first DIE stayed at <code>0xb</code>, the header stayed 11 bytes, and the string forms stayed the same pair &mdash; <code>DW_FORM_string</code> and <code>DW_FORM_strp</code> in both, with <code>DW_FORM_line_strp</code> appearing only in version 5. The version number moved the compiler's decisions about what to record; it did not move the container's geometry.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>A reader that handles all four files above correctly, and what each of the three varying quantities costs it:</p>
                <div class="formula">
header = read 4 bytes at the section start
if header == 0xffffffff:
    offset_size = 8
    header = read 8 more bytes
else:
    offset_size = 4
unit_length   = read unsigned of offset_size bytes
version       = read 2 bytes

if version &gt;= 5:
    unit_type = read 1 byte
address_size  = read 1 byte
abbrev_offset = read unsigned of offset_size bytes
first_die     = position after the header
else:
    abbrev_offset = read unsigned of offset_size bytes
address_size  = read 1 byte
first_die     = position after the header
</div>
                <p>Three consequences worth stating plainly:</p>
                <ul>
                    <li><strong>Address size does not affect any field width in the header or the DIE tree.</strong> It appears in exactly one place in the header, and everywhere else it is implied by a form. <code>DW_FORM_addr</code> is the only form whose width it changes, and that form is becoming rare for exactly the reason shown above. A reader that hardcodes 8 for "address size" is not wrong on most files and is wrong on every 32-bit one.</li>
                    <li><strong>Offset size is not the target's business.</strong> The <code>0xffffffff</code> escape at the front of every section is how a format says "the width of the widths just changed". Nothing about the target machine influences it, and a reader that computes it from the pointer width is wrong in a way that only shows up on files over four gigabytes &mdash; the rarest possible place to discover a bug.</li>
                    <li><strong>Version is the only one you must branch on.</strong> Address size and offset size are values you <em>read</em> and then use. Version is a value you read and then <em>change your parser's shape</em> on, because version 5 moved the header, added a field, added <code>.debug_line_str</code>, introduced <code>DW_FORM_addrx</code> and <code>DW_FORM_rnglistx</code>, and gave the list sections their own opcodes. Nothing else in the format changes its structure between versions.</li>
                </ul>
                <p>Now the honest limit of what was just demonstrated. Four configurations is evidence, not proof. There are producers and targets this experiment did not touch: DWARF 4, <code>DWARF64</code> format, a non-zero <code>offset_entry_count</code>, the split-debugging sections, and a 64-bit target's <code>address_size</code> under DWARF 2 or 3. Each of those is a real branch in a reader, and none of them was tested here. The experiment established <em>which dimensions vary and which do not</em>, which is the thing that was missing; it did not establish that every combination works.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ readelf --debug-dump=abbrev types_v2.o | grep -oE 'DW_FORM_(str|line_str)[a-z_]*' | sort -u
$ readelf --debug-dump=abbrev types_v3.o | grep -oE 'DW_FORM_(str|line_str)[a-z_]*' | sort -u
$ readelf --debug-dump=abbrev types_i386.o | grep -oE 'DW_FORM_(str|line_str)[a-z_]*' | sort -u
$ gcc -gdwarf-4 -O0 -c t.c -o types_v4.o   # the one version not tried here</code></pre>
                <ul>
                    <li><strong>Find the version 4 case.</strong> It is the one version this course has not exercised, and it is the last one before the version 5 restructuring. Compile it, read the header by hand, and check the first DIE offset. Predict before you look: if you predict <code>0xb</code> you have understood that version 4 is on the old side of the split.</li>
                    <li><strong>Diff the abbrev tables across all four.</strong> The abbreviation table is where a version bump does its visible work, because it lists every form the producer chose. Diffing <code>types_v2</code> against <code>types_i386</code> and listing which forms appear in one and not the other is the fastest way to enumerate what a version actually changed.</li>
                    <li><strong>Find a <code>DW_FORM_addr</code> to prove the indexing point.</strong> The version 2 and 3 builds predate the indexed forms, so some address in them must be stored inline. Find one, note its width in each file, and confirm the unit length changes when you remove it. That is the mechanism behind the identical 165-byte units, observed directly.</li>
                    <li><strong>Confirm the <code>0xffffffff</code> escape is really an escape.</strong> You will not produce a <code>DWARF64</code> file without gigabytes of debug info, so instead read the code path: find a section you can inspect, and reason about where the sentinel would have to be checked. Being explicit about a branch you have never executed is better than being silent about it.</li>
                    <li><strong>Ask what a 32-bit <em>binary</em> with <code>DWARF64</code> would look like.</strong> Write down what the header bytes would have to be, given a 4-byte <code>address_size</code> and an 8-byte offset size. If your answer is not obvious, that is the gap this concept was pointing at.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Two compilation units come out of the same build system. One is from a 32-bit target with DWARF 5 and has <code>unit_length = 165</code> with its first DIE at offset <code>0xc</code>. The other is from a 64-bit target with DWARF 5 and also has <code>unit_length = 165</code>, first DIE at <code>0xc</code>. Both use <code>DW_FORM_addrx</code>. A third unit is from a 64-bit target with DWARF 3, has <code>unit_length = 263</code>, first DIE at <code>0xb</code>. What accounts for all three of those observations?</p>
                <div class="quiz" id="quiz-dwarf-portability-1">
                    <button class="quiz-option" data-correct="true" data-explain="Three separate effects, and none of them is the one most people expect. The identical lengths are the indexed forms: DW_FORM_addrx stores a small index rather than the address, so the target's address width never appears in the DIE tree at all. The 0xc versus 0xb first-DIE offset is the version 5 header's extra unit_type byte, eleven bytes before version 5 and twelve after. And the 263 versus 165 length is not the address width either: it is the content, because the version 2/3 build records a different and larger set of attributes, plus the older forms carry inline addresses. Address width, version, and content are three independent axes, and conflating any two of them produces a reader that is right about one configuration and wrong about all the others." onclick="checkQuiz('quiz-dwarf-portability-1', this)">Three independent things: the indexed address forms mean address width never appears in the DIE tree, so the 32-bit and 64-bit units match; version 5 added <code>unit_type</code> to the header, making it 12 bytes instead of 11 and pushing the first DIE from <code>0xb</code> to <code>0xc</code>; and the much longer version 3 unit is <em>content</em>, because the older producer records a larger attribute set and stores some addresses inline</button>
                    <button class="quiz-option" data-correct="false" data-explain="That is the intuitive answer and it is wrong here, because DW_FORM_addrx means the address width never enters the DIE tree. The two 165-byte units are the evidence: same length despite 4-byte versus 8-byte addresses. If address width were driving the layout, the 32-bit unit would be markedly shorter." onclick="checkQuiz('quiz-dwarf-portability-1', this)">The 32-bit target needs half as many bytes for every address, so its unit is shorter, and the version 3 unit is longer because the older forms store more data per DIE</button>
                    <button class="quiz-option" data-correct="false" data-explain="The 32-bit unit is exactly the same length as the 64-bit one, 165 in both cases, so address width is demonstrably not affecting the layout. The two version 5 units also agree at 0xc, so the version is not what separates 0xb from 0xc either. Something in the header layout does, and it is the one field version 5 added." onclick="checkQuiz('quiz-dwarf-portability-1', this)">The 32-bit unit is the same length because the smaller address size cancels the larger unit_type field, and the version 3 unit is longer because it has no indexed forms at all</button>
                    <button class="quiz-option" data-correct="false" data-explain="All three are DWARF32: unit_length fits in four bytes in every case, and nothing in the data suggests an 8-byte offset size. Offset size is a property of the total size of the debug information, not of the target, so the target architectures are irrelevant to it. Mentioning it here is a plausible-sounding distractor that the unit lengths themselves rule out." onclick="checkQuiz('quiz-dwarf-portability-1', this)">The 32-bit target is more likely to be <code>DWARF64</code>, since fewer bits are available for offsets and the format widens to compensate</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your DWARF reader passes its entire test suite on 64-bit Linux binaries from GCC and Clang, all DWARF 5, all under a megabyte. It fails in the field on two classes of file: binaries from a 32-bit Android toolchain, and a single large binary from a Windows build. Both failures are "wrong values, no error". You now have a model of the three varying quantities. What is your diagnosis for each, and what is the one change that would distinguish them from a bug in your DIE parser?</p>
                <div class="quiz" id="quiz-dwarf-portability-2">
                    <button class="quiz-option" data-correct="true" data-explain="Each failure has a different varying quantity behind it, and that is what makes them diagnosable rather than mysterious. The 32-bit Android binaries are the address_size case: a reader hardcoding 8-byte addresses reads past the end of every inline DW_FORM_addr, shifting every subsequent field and corrupting the whole DIE tree, which is why the failure is total rather than partial. The large Windows binary is the offset_size case, triggered not by the target but by the file exceeding four gigabytes of debug info, so the 0xffffffff sentinel appears and every offset becomes eight bytes. Neither failure would be caught by a DIE parser that is otherwise correct, and both are fixed by reading the two widths from the header instead of assuming them. The general lesson is that the widths are data, and a parser that treats them as constants will be right exactly until the first file that is not the common case." onclick="checkQuiz('quiz-dwarf-portability-2', this)">Two different quantities, so two different fixes. The 32-bit Android files are the <code>address_size</code> case: the reader is assuming 8-byte addresses and every inline <code>DW_FORM_addr</code> in a 32-bit unit is read with the wrong width, which shifts everything after it. The large Windows binary is the <code>DWARF64</code> case: it crossed four gigabytes of debug info, so every offset is 8 bytes behind a <code>0xffffffff</code> sentinel. Both are fixed by reading the widths out of the header instead of assuming them</button>
                    <button class="quiz-option" data-correct="false" data-explain="A version gate is worth checking but it does not fit either report. Both field producers here are modern, and the reported failures are on a subset of files rather than a whole class, which is the opposite of what a version gate produces. The two cases differ in what is true about the files rather than in when they were produced, which points at the widths." onclick="checkQuiz('quiz-dwarf-portability-2', this)">Both are version-gate failures: the reader assumes version 5 and the Android toolchain and the large Windows build both emit version 4, so the eleven-byte header assumption shifts the first DIE</button>
                    <button class="quiz-option" data-correct="false" data-explain="A common 32-bit Android toolchain emits DWARF 2 or 3 for compatibility, so the version explanation is not impossible in the abstract. But it does not account for the large Windows binary, and more importantly it predicts a uniform failure across an entire producer rather than a subset, and the report says the reader passes on many files from the same test suite. Treating both failures as one cause would leave you unable to explain the second one." onclick="checkQuiz('quiz-dwarf-portability-2', this)">Both failures are the same cause: the 32-bit toolchain emits an older DWARF version, and adding a <code>version &lt; 5</code> branch for the eleven-byte header fixes both</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a reader that gets a whole class of files wrong usually has a constant where the format has a field. Before debugging the parse, list every number the file states about itself &mdash; version, address size, offset size, segment size, entry counts &mdash; and check that each one is actually read from the file rather than assumed.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The <code>address_size</code> finding is the same fact you met in the <a href="/courses/dwarf/lessons/dwarf-frames">CFI concept</a>, arriving from the other direction. <code>DW_EH_PE</code> encoding bytes carry a pointer width, and a 32-bit build's unwind data is correspondingly narrower. Debug info and unwind info are the two halves of a debugger's model of the machine, and they agree on this machine's width because the format records it in the same way &mdash; declared once, per section, and used to parse everything after.</p>
                <p>The indexed-address result also explains something from <a href="/courses/dwarf/lessons/dwarf-split">the split-debugging concept</a>. Split units emit <code>DW_FORM_addrx</code> with abandon, and a split unit is explicitly not address-bearing at all &mdash; so the producer that most needs the "addresses live elsewhere" indirection is the one that uses it most. The mechanism was not invented for split debugging; split debugging took advantage of a mechanism that already existed.</p>
                <p>One topic remains, and it is the one place where a DWARF file is not a file: the packaged form that lets a debug session travel without shipping the objects it describes.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-packages">Packages</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-rnglists">Previous: Range Lists</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-packages">Next: Packages</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
