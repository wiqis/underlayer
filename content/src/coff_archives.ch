// COFF Course — Module 3: Containers and Variants
// Concept: the .lib archive container, its member headers, and its two symbol indexes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_archives() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The .lib Archive — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>The .lib Archive</h1>
            <div class="lesson-meta">19 min &middot; Module 3: Containers and Variants &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Static libraries are the one part of a Windows build that is <em>not</em> COFF. A <code>.lib</code> you pass to the linker is a Unix <code>ar</code> archive containing COFF objects, byte for byte the objects Module 1 decoded. Nothing inside it is Windows-specific except the choice of extension.</p>
                <p>That is worth understanding for two reasons. First, the container has a magic number that works, which makes a nice contrast with <a href="/courses/coff/lessons/coff-bigobj">bigobj</a> and with the object format itself. Second, the archive carries a <strong>symbol index</strong> that exists so a linker can answer &ldquo;which of these hundred members defines <code>printf</code>?&rdquo; without opening all hundred &mdash; and that index turns out to be the tidiest offset-based lookup structure in the whole toolchain.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three pieces, in this order:</p>
                <ol>
                    <li><strong>An 8-byte magic:</strong> <code>!&lt;arch&gt;\n</code> &mdash; ASCII, plus a newline.</li>
                    <li><strong>One or more index members</strong>, named <code>/</code>. There is no requirement that there be only one, and in practice there are two with different contents.</li>
                    <li><strong>The object members</strong>, each preceded by a fixed 60-byte ASCII header.</li>
                </ol>
                <p>The 60-byte header is the part worth memorising, because every field in it is text and the field boundaries are defined by their widths, not by delimiters:</p>
                <div class="formula">
offset  width  field
  0      16    name      (ASCII, space-padded; "/" or "//" for the indexes)
 16      12    mtime     (decimal, usually 0)
 28       6    uid       (decimal, usually 0)
 34       6    gid       (decimal, usually 0)
 40       8    mode      (octal, e.g. "644  ")
 48      10    size      (decimal BYTES of the member body)
 58       2    terminator  the two bytes 0x60 0x0A, i.e. "`" and newline
                </div>
                <p>Two consequences follow immediately. The size field is <strong>decimal</strong>, not hexadecimal, so a member of 823 bytes is stored as <code>823      </code> and one of 16 bytes as <code>16       </code> &mdash; a reader that assumes hex will be wrong by a factor of sixteen on most members. And the terminator is a fixed two-byte sequence, so a parser can detect a truncated or misaligned archive immediately rather than discovering it as garbage further in.</p>
                <div class="callout callout-warn">
                    <strong>Members are padded to an even length.</strong> After a member body, if the size was odd, one pad byte follows before the next header. The 60-byte header keeps the next header even-aligned, so the padding is always exactly one byte at most &mdash; but a reader that computes offsets as <code>60 + size</code> without the parity fix will land one byte early and read a corrupt header on every odd-sized member. In the sample below, the 40-byte and 46-byte index members are even, and the objects are 823 and 802 bytes, so the parity rule happens not to bite &mdash; which is exactly why it is worth stating.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Built here from two real objects, both produced by the same clang invocation as Module 1:</p>
                <pre><code>$ cat lib1.c
int lib_add(int a, int b) &#123; return a + b; &#125;
int lib_val = 11;
$ cat lib2.c
int lib_mul(int a, int b) &#123; return a * b; &#125;

$ clang --target=x86_64-pc-windows-msvc -c lib1.c -o lib1.obj
$ clang --target=x86_64-pc-windows-msvc -c lib2.c -o lib2.obj
$ llvm-ar rcs demo.lib lib1.obj lib2.obj
$ file demo.lib
demo.lib: current ar archive</code></pre>
                <p><code>file</code> calls it a &ldquo;current ar archive&rdquo;, which is a Unix description of a file that Windows tools call a static library. Here is the first sixteen bytes:</p>
                <div class="hex-dump">
                    <pre>0000: 213c 6172 6368 3e0a 2f20 2020 2020 2020  !&lt;arch&gt;./
0010: 2020 2020 2020 2020 3020 2020 2020 2020          0
      |&mdash; magic: "!&lt;arch&gt;" + \n &mdash;| |&mdash; name "/" &mdash;| |&mdash; mtime "0" &mdash;</pre>
                </div>
                <p>And the whole 1960-byte file, member by member, decoded by a parser written from the archive format rather than from <code>llvm-ar</code>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Member</th><th scope="col">Header at</th><th scope="col">Body at</th><th scope="col">Size</th><th scope="col">Name field</th><th scope="col">What it is</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>0x8</td><td>0x44</td><td>40</td><td><code>/</code></td><td>symbol index, plain form</td></tr>
                        <tr><td>1</td><td>0x6c</td><td>0xa8</td><td>46</td><td><code>/</code></td><td>symbol index, extended form</td></tr>
                        <tr><td>2</td><td>0xd6</td><td>0x112</td><td>823</td><td><code>lib1.obj/</code></td><td>a COFF object</td></tr>
                        <tr><td>3</td><td>0x44a</td><td>0x486</td><td>802</td><td><code>lib2.obj/</code></td><td>a COFF object</td></tr>
                    </tbody>
                </table>
                <p>The object members are the files from Module 1, unchanged. The decoder reads <code>lib1.obj</code>&rsquo;s member and finds machine 0x8664, 9 sections, a symbol table and 11 named symbols &mdash; the same values the standalone object has, which is the check that the archive did not rewrite anything.</p>
                <h3>The two indexes, which are not the same structure</h3>
                <p>Both are named <code>/</code>. The first four bytes of the body tell you which one you have, and they are <strong>not</strong> the same size, layout, or byte order.</p>
                <p><strong>Member 0, the plain form.</strong> 40 bytes: a big-endian count, then one big-endian value per symbol.</p>
                <div class="formula">
00 00 00 03   count = 3
00 00 00 d6   symbol 0 -&gt; file offset 0xd6
00 00 00 d6   symbol 1 -&gt; file offset 0xd6
00 00 04 4a   symbol 2 -&gt; file offset 0x44a
6c 69 62 5f 61 64 64 00   "lib_add\0"
6c 69 62 5f 76 61 6c 00   "lib_val\0"
6c 69 62 5f 6d 75 6c 00   "lib_mul\0"
                </div>
                <p>Two things to notice. The values are <strong>offsets of member headers in the file</strong>, not offsets into this index: 0xd6 is where <code>lib1.obj</code>&rsquo;s header starts, and 0x44a is <code>lib2.obj</code>&rsquo;s. So <code>lib_add</code> and <code>lib_val</code> both point at the same member, which is correct &mdash; they are both defined there. And the three names that follow the offset array are stored in <em>link order</em>, not sorted: <code>lib_add</code>, <code>lib_val</code>, <code>lib_mul</code>.</p>
                <p><strong>Member 1, the extended form.</strong> 46 bytes, starting with the marker <code>02 00 00 00</code>:</p>
                <div class="formula">
02 00 00 00   marker = 2 (extended form)
00 00 00 d6   member header offset
00 00 04 4a   member header offset
03 00 00 00   count = 3        &lt;-- LITTLE-endian, unlike the index above
01 00 02 00 01 00              two bytes of binding flags per symbol
6c 69 62 5f 61 64 64 00   "lib_add\0"
6c 69 62 5f 6d 75 6c 00   "lib_mul\0"
6c 69 62 5f 76 61 6c 00   "lib_val\0"
                </div>
                <p><strong>The same three symbols, sorted, in a different byte order.</strong> <code>lib_add</code>, <code>lib_mul</code>, <code>lib_val</code> is alphabetical; the plain index had them in link order. And the count is little-endian where the plain index's count was big-endian &mdash; a difference that is easy to miss because on this machine both encodings of the <em>member offsets</em> happen to agree, since each value's low byte comes first and the rest are zeros.</p>
                <p>The practical consequence: <strong>a reader must not assume either list is sorted</strong>, and must read each index with the byte order its own marker implies. Binary-searching the plain index would work here by luck and fail the moment a symbol is added out of order.</p>
                <h3>Names longer than sixteen characters</h3>
                <p>The name field is sixteen bytes, so <code>a_very_long_member_name_here.obj</code> does not fit. The escape is a third special member name:</p>
                <pre><code>  member 2  header at 0xd6  name '//'   size 34
      LONG NAME TABLE: b'a_very_long_member_name_here.obj\x00\n'
  member 3  header at 0x134 name '/0'   size 823
      -> a COFF object: machine=0x8664, 11 named symbols</code></pre>
                <p>The <code>//</code> member holds the long names, NUL-terminated, each followed by <code>/</code>. The object&rsquo;s name field is then <code>/0</code>: a slash and the <em>decimal offset</em> into that table. This is the same idea as a COFF section name stored as <code>/17</code> in <a href="/courses/coff/lessons/coff-section-table">the section header concept</a>, and as the mangled symbol name stored as a string-table offset in <a href="/courses/coff/lessons/coff-string-table">the string table concept</a>. Three structures in one format, one idea: when eight or sixteen bytes is not enough, store a number.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The question the index exists to answer: <em>the linker needs <code>lib_add</code>. Which member is it in?</em></p>
                <ol>
                    <li><strong>Check the magic.</strong> Bytes 0 to 7 are <code>!&lt;arch&gt;\n</code>. Not an archive &rarr; stop. Two bytes would do, and unlike a COFF object this format is identifiable.</li>
                    <li><strong>Find the index.</strong> The first member&rsquo;s name field is <code>/</code> and its body does not begin with the <code>0x02</code> marker, so it is the plain form. Read the count big-endian: 3.</li>
                    <li><strong>Walk the three values.</strong> <code>0xd6</code>, <code>0xd6</code>, <code>0x44a</code>. These are file offsets of member headers.</li>
                    <li><strong>Match the name.</strong> The names follow the offset array, in the same order, NUL-terminated. Scanning them, <code>lib_add</code> is first, so its defining member is the one whose header is at 0xd6.</li>
                    <li><strong>Open that member.</strong> Its header is 60 bytes, so its body starts at 0x112 and runs 823 bytes. Seek past the header, and you are looking at <code>lib1.obj</code> &mdash; the same COFF object you would have had on disk, with its own symbol table at its own offsets.</li>
                    <li><strong>Read the symbol from the object</strong>, not from the index. The index told you which file; the file&rsquo;s symbol table is the authority on the offset. This is the same index-versus-source-of-truth split as <a href="/courses/dwarf/lessons/dwarf-lookup">.debug_pubnames</a>, and for the same reason: the index is derived and can be wrong without the object being wrong.</li>
                </ol>
                <p>Six steps, and step 5 is the only one that touches real object data. That is the entire value of the index: without it, answering &ldquo;where is <code>lib_add</code>&rdquo; means opening both members and reading both symbol tables.</p>
                <div class="callout callout-tip">
                    <strong>Why an archive holds a whole object rather than a piece of one.</strong> A static library is not a linker input in the way an object is; it is a <em>search path</em>. The linker pulls in a member only if it is needed to resolve a currently-undefined symbol, and pulling one in can create new undefined symbols, which pulls in more. That is why the index must map a <em>symbol</em> to a <em>whole member</em>: the unit of extraction is the object file, and the index exists to find the right one. It is also why an archive of two objects, one of which defines nothing anybody wants, costs a header and an index entry and nothing else.
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ cd courses/coff/assets/samples
$ python3 ar_decode.py demo.lib
$ llvm-ar t demo.lib
$ llvm-nm demo.lib</code></pre>
                <p>Four experiments, each of which teaches something the tools do not tell you:</p>
                <ul>
                    <li><strong>Find the size field&rsquo;s radix.</strong> <code>lib1.obj</code> is 823 bytes on disk and the header says <code>823     </code>. Then look at a member whose size happens to contain only digits that are valid hex &mdash; a 16-byte member reads <code>16       </code>, which is 22 in hex. Any reader assuming hex is wrong on almost every real member, and wrong silently.</li>
                    <li><strong>Force an odd-sized member</strong> and watch the parity padding. A member of odd size is followed by one pad byte; a reader computing <code>header + 60 + size</code> without it lands one byte early and reads a header full of nonsense. Both objects in <code>demo.lib</code> happen to be even-sized, so the rule never fires here &mdash; which is why it is worth constructing a case that does.</li>
                    <li><strong>Compare the two indexes</strong> with <code>xxd</code>. Member 0 has its count as <code>00 00 00 03</code> and member 1 as <code>03 00 00 00</code>. Same file, same number, two byte orders, distinguished only by a marker in the first four bytes.</li>
                    <li><strong>Check whether either list is sorted.</strong> Member 0 is in link order and member 1 is alphabetical. Add a third object defining a symbol beginning with <code>a</code> and rebuild: the plain index will list it last, the extended one first.</li>
                </ul>
                <p>And the test of whether you understand the whole thing: extract <code>lib1.obj</code> from <code>demo.lib</code> by hand &mdash; skip 8 bytes of magic, skip two 60-byte headers plus their index bodies, land on 0x112, take 823 bytes &mdash; and confirm it is byte-identical to the <code>lib1.obj</code> on disk. If it is, you have understood that the archive is a container and not a re-encoding.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a member header reports <code>size = 16</code>. How many bytes of member body follow, and what does the <em>next</em> member header start at relative to this one?</p>
                <div class="quiz" id="quiz-coff-archives-1">
                    <button class="quiz-option" data-correct="true" data-explain="The size field is decimal, so sixteen bytes of body, and the next header begins 60 + 16 = 76 bytes on. The parity rule would not add a pad byte here because 16 is already even. Had the size been 15, the next header would still be even-aligned and a single pad byte would sit between the body and the next header, putting the next header at 60 + 15 + 1." onclick="checkQuiz('quiz-coff-archives-1', this)">16 bytes of body, and the next header is 76 bytes further on &mdash; 60 for this header plus 16 for the body. Sixteen is even, so no pad byte is needed</button>
                    <button class="quiz-option" data-correct="false" data-explain="The size field is decimal, so 16 means sixteen bytes, not 0x16 = 22. A reader that assumes hexadecimal is wrong on nearly every real member and gets no error for it, because 22 is also a plausible body size and the next header will still look superficially reasonable." onclick="checkQuiz('quiz-coff-archives-1', this)">22 bytes of body, because the size field is hexadecimal, so the next header is 82 bytes further on</button>
                    <button class="quiz-option" data-correct="false" data-explain="The pad byte is needed only when the size is odd, and 16 is even, so nothing is inserted. The rule keeps the next 60-byte header at an even offset, which is why it exists at all &mdash; an odd-sized body would otherwise push the following header to an odd offset." onclick="checkQuiz('quiz-coff-archives-1', this)">17 bytes of body, because an odd-sized member is always followed by one pad byte to keep the next header aligned</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a tool that lists the members of a <code>.lib</code>. It works on every archive until it hits one built by a different toolchain, and then it reports members with empty names and nonsensical sizes &mdash; but the magic checked out and the file is a genuine archive. What are the two most likely causes, and what distinguishes them?</p>
                <div class="quiz" id="quiz-coff-archives-2">
                    <button class="quiz-option" data-correct="true" data-explain="The first member is not guaranteed to be the symbol index - it can be the GNU extended form, which begins with a 0x02 marker, and it can also be the // long-name table when any member has a long name. Both of those would be misread as an object or as a plain index, producing exactly the empty names and bad sizes described. Test the member name against /, // and /digits before deciding what a member is, and read each index with the byte order its marker implies." onclick="checkQuiz('quiz-coff-archives-2', this)">The tool assumed the first member is always the plain symbol index, and on this archive it is the GNU extended form (marker <code>0x02</code>) or a <code>//</code> long-name table. Distinguish them by the member name and the marker, not by position</button>
                    <button class="quiz-option" data-correct="false" data-explain="A wrong byte order for the size field would produce a plausible but incorrect size, which usually means a wrong offset and a garbage next member rather than an empty name. And since the two indexes in one archive can differ in byte order, the more likely cause is treating them as the same structure, which is the first answer." onclick="checkQuiz('quiz-coff-archives-2', this)">The tool read the size field as binary instead of decimal, so every offset after the first member was wrong and it walked off into padding</button>
                    <button class="quiz-option" data-correct="false" data-explain="A 60-byte header is fixed by the format and is the same in every implementation, so a toolchain writing a different header size would not be an archive at all. The variation between archives is in which special members appear and in what the indexes contain, not in the header geometry." onclick="checkQuiz('quiz-coff-archives-2', this)">The other toolchain used a different header size, so the 60-byte constant is wrong for that archive and every member boundary is misplaced</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a format uses a small number of reserved names to mean special things, dispatch on those names before you dispatch on anything else. A tool that assumes &ldquo;the first record is the interesting one&rdquo; will work on most inputs and fail on exactly the ones that were produced by a different implementation.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The archive&rsquo;s symbol index is the same structure as the <a href="/courses/elf/lessons/dynamic-section">ELF dynamic symbol table</a> in purpose and the opposite in mechanism: both answer &ldquo;which file provides this symbol&rdquo;, and both exist so the answer can be found without opening everything. The ELF course covers the <code>.gnu.hash</code> acceleration on top of that table, which is the next step past what an archive does.</p>
                <p>The offset-for-name trick &mdash; <code>/17</code> in a section header, a zero dword plus an offset in a symbol name, <code>/0</code> into a long-name table &mdash; is the format&rsquo;s single most repeated idea, and the <a href="/courses/dwarf/lessons/dwarf-file-tables">DWARF file tables</a> concept shows it in a fourth format. Learning to recognise &ldquo;this small field is an index, not a value&rdquo; is probably the single most transferable thing in either course.</p>
                <p>One field remains, and it is the module&rsquo;s smallest concept: a section header slot that is always zero.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-line-numbers">Line Numbers</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-bigobj">Previous: bigobj</a></span>
                <span><a href="/courses/coff/lessons/coff-line-numbers">Next: Line Numbers</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
