// COFF Course — Module 2: Symbols and Relocations
// Concept: the string table and the 8-byte name union.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_string_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The String Table — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>The String Table</h1>
            <div class="lesson-meta">15 min &middot; Module 2: Symbols and Relocations &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A C symbol is a handful of characters. A C++ symbol is a hundred or more. A section name is usually short, but not always. COFF gives every name exactly eight bytes of room and then runs out.</p>
                <p>The string table is the overflow, and it is also the place where two different name fields in two different structures both end up. Understanding it means being able to resolve a symbol's name and a section's name from the same pool &mdash; which is exactly what a linker does, and what you will do when you read one of these files.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three facts, and they compose into everything:</p>
                <ol>
                    <li>The string table is <strong>not pointed at by any header field</strong>. Its position is implied: it starts at <code>PointerToSymbolTable + NumberOfSymbols &times; 18</code>. There is no offset to read.</li>
                    <li>Its <strong>first four bytes are its own total size</strong>, including those four bytes. That is how you know where it ends, and therefore where the file ends.</li>
                    <li>Every string is <strong>NUL-terminated</strong>, and every reference to one is a <strong>4-byte offset from the start of the table</strong> &mdash; so the smallest valid offset is 4, not 0.</li>
                </ol>
                <p>Point 3 is the one to hold on to. Offset 0 is the size field, not a string, which is why no real name ever has offset 0 and why a name of "0" is a bug rather than a valid reference.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Our file's string table, in full. 57 bytes, at file offset 0x576, running to the last byte of the file:</p>
                <div class="hex-dump">
                    <pre>00000576: 3900 0000 6361 6c6c 5f74 6872 6f75 6768  9....call_through
00000586: 002e 6c6c 766d 5f61 6464 7273 6967 003f  ..llvm_addrsig.?
00000596: 3f5f 4340 5f30 3350 4c48 4646 4c49 4840  ?_C@_03PLHFFLIH@
000005a6: 7074 723f 2441 4140 00                    ptr?$AA@.</pre>
                </div>
                <p>Split it:</p>
                <ul>
                    <li><strong>Bytes 0-3:</strong> <code>39 00 00 00</code> = 57. The table's own size.</li>
                    <li><strong>Bytes 4-15:</strong> <code>call_through</code> + NUL. Offset <strong>4</strong>.</li>
                    <li><strong>Bytes 17-30:</strong> <code>.llvm_addrsig</code> + NUL. Offset <strong>17</strong>.</li>
                    <li><strong>Bytes 31-56:</strong> <code>??_C@_03PLHFFLIH@ptr?$AA@</code> + NUL. Offset <strong>31</strong>.</li>
                </ul>
                <p>And the arithmetic closes exactly, which is the check that the table is fully understood:</p>
                <div class="formula">
table starts at  0x348 + 31 &times; 18  =  0x576<br>
declared size                              57  =  0x39<br>
table ends at      0x576 + 57           =  0x5AF<br>
file size                                    1455 = 0x5AF  &lt;- MATCH
                </div>
                <p>Byte 16 is the NUL that ends <code>call_through</code>; byte 17 starts the next string. Byte 30 ends <code>.llvm_addrsig</code>; byte 31 starts the mangled name. Nothing is padded, and nothing is wasted beyond the one NUL after each string.</p>
                <h3>The 8-byte name union</h3>
                <p>Both the symbol record and the section header begin with the same eight-byte union:</p>
                <div class="formula">
if bytes 0-3 are 00 00 00 00:  bytes 4-7 = 4-byte offset into the string table<br>
otherwise:                  the 8 bytes ARE the name, NUL-padded
                </div>
                <p>Two verified examples from the same file:</p>
                <p><strong>Section 9's <code>Name</code> field</strong> is not a name and not an offset &mdash; it is the <em>text</em> <code>/17</code>:</p>
                <div class="hex-dump">
                    <pre>00000154: 2f31 3700 0000 00                          /17.....</pre>
                </div>
                <p>Slash, then the decimal digits <code>17</code>. String-table offset 17 is <code>.llvm_addrsig</code>, which is exactly what <code>llvm-readobj</code> reports. Note that this is a <em>different</em> encoding from the symbol union: a leading slash plus ASCII decimal, not a zero dword plus a binary offset. Two conventions, both landing in the same pool.</p>
                <p><strong>Symbol 12's <code>Name</code> field</strong> uses the zero-dword form:</p>
                <div class="hex-dump">
                    <pre>symbol 12 at 0x348 + 12*18 = 0x420:
00000420: 0000 0000 1f00 0000                       ........
                 |______| |______|
              zero dword  offset = 31</pre>
                </div>
                <p>Offset 31 is <code>??_C@_03PLHFFLIH@ptr?$AA@</code> &mdash; the MSVC-mangled name of the <code>"ptr"</code> string literal, which is 25 characters and cannot fit in eight bytes. Every other name in this file is short enough to be inline, which is why this is the only symbol in the file that uses the pool.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Three names, three mechanisms, one pool. This is the whole idea of the concept in a single table:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Name</th><th scope="col">Where it lives</th><th scope="col">Encoding</th><th scope="col">Resolves to</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>.text</code></td><td>inline, section 1 header</td><td>8 bytes, NUL-padded</td><td>itself, no lookup</td></tr>
                        <tr><td><code>.llvm_addrsig</code></td><td>table offset 17</td><td><code>/17</code> in the name field</td><td>offset 17</td></tr>
                        <tr><td><code>??_C@_03PLHFFLIH@ptr?$AA@</code></td><td>table offset 31</td><td>zero dword + offset</td><td>offset 31</td></tr>
                    </tbody>
                </table>
                <p>Now decode all three from the file by hand and confirm with the tools:</p>
                <pre><code>$ xxd -s 0x154 -l 8 sample_msvc.obj     # section 9 name
00000154: 2f31 3700 0000 00                        /17.....

$ xxd -s 0x420 -l 8 sample_msvc.obj     # symbol 12 name
00000420: 0000 0000 1f00 0000                    ....

$ xxd -s 0x576 -l 57 sample_msvc.obj     # the table itself
00000576: 3900 0000 6361 6c6c 5f74 6872 6f75 6768  9....call_through
...

$ llvm-readobj --sections sample_msvc.obj | grep llvm_addrsig
    Name: .llvm_addrsig

$ llvm-readobj --symbols sample_msvc.obj | grep PLHFFLIH
    Name: ??_C@_03PLHFFLIH@ptr?$AA@</code></pre>
                <p>Three reads, three mechanisms, one correct answer each. The mechanism differs every time; the pool does not.</p>
                <p>One detail about the mangled name is worth a sentence, because it is a portability trap rather than a COFF one. <code>??_C@_03PLHFFLIH@ptr?$AA@</code> is a Microsoft-specific encoding of the C++ symbol for the string literal <code>"ptr"</code> &mdash; the <code>??_C@</code> prefix marks a string-literal symbol and the rest is a hash and a length. The GNU-dialect build of the same source does not produce it at all; it has eight sections rather than nine, because it did not merge the string literals into a separate COMDAT <code>.rdata</code>. <strong>The container is identical; the dialect decides what is in it.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=x86_64-pc-windows-msvc -c sample.c -o sample_msvc.obj
$ xxd -s 0x576 sample_msvc.obj          # the whole string table, 57 bytes
$ llvm-objdump -h sample_msvc.obj | tail -4</code></pre>
                <p>Three things to confirm, in order:</p>
                <ul>
                    <li><strong>The size field is 57 and the table is 57 bytes long.</strong> If the last byte of the file is not a NUL, you mis-derived the start offset.</li>
                    <li><strong>The start offset comes out of arithmetic, not a field.</strong> <code>PointerToSymbolTable + NumberOfSymbols &times; 18</code> &mdash; 0x348 + 558 = 0x576. There is no <code>PointerToStringTable</code> field, and looking for one is a common and fruitless hunt.</li>
                    <li><strong>No string starts at offset 0.</strong> Offset 0 is the size. If your resolver hands back "0x39000000" for a name, it has forgotten the four-byte header.</li>
                </ul>
                <p>To see the growth mechanism for yourself, compile something with a long C++ name:</p>
                <pre><code>$ clang++ --target=x86_64-pc-windows-msvc -c comdat.cpp -o comdat.obj
$ llvm-objdump -h comdat.obj | head -6
$ llvm-readobj --symbols comdat.obj | grep -c 'Name:'
$ llvm-readobj --symbols comdat.obj | grep 'Name: .*::' | head -3</code></pre>
                <p>Look at how many names in the C++ object are long, and how the table grows to hold them while the container stays the same 40- and 18-byte records.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a symbol's eight-byte name field is <code>00 00 00 00 1F 00 00 00</code>. What is the symbol called, and how do you get there?</p>
                <div class="quiz" id="quiz-coff-string-table-1">
                    <button class="quiz-option" data-correct="true" data-explain="The first four bytes being zero is the signal that this is not an inline name. The next four bytes are a little-endian offset, 0x1f = 31. Add that to the string table's base of 0x576 and read from there: the 25 characters are the MSVC-mangled name of the &quot;ptr&quot; string literal. The inline form simply was not wide enough for it." onclick="checkQuiz('quiz-coff-string-table-1', this)">The first four bytes being zero marks the long-name form; the offset is 0x1F = 31, and string-table offset 31 is <code>??_C@_03PLHFFLIH@ptr?$AA@</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="All-zero first four bytes could mean the name is genuinely empty, or it could be the long-name marker. The distinguishing signal is that bytes 4-7 are non-zero (0x1f), which is an offset. A tool that only checks for an all-zero field would call this symbol unnamed." onclick="checkQuiz('quiz-coff-string-table-1', this)">The name is empty &mdash; an all-zero field means the symbol has no name, which is legal for some aux-only records</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x1f is the string-table offset, not a file offset. Adding it to the file base would land in the middle of the .pdata relocation table. Offsets into the string table are always relative to the table's own start at 0x576." onclick="checkQuiz('quiz-coff-string-table-1', this)">The name is stored inline and happens to be <code>0x1F</code>, the ASCII control character</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your COFF reader wants to print a section name. It reads the eight-byte <code>Name</code> field, checks whether the first dword is zero, and if not strips the NUL padding and prints it. On <code>sample_msvc.obj</code> it prints <code>llvm_addr</code> for section 9. What is wrong, and what are the two rules your resolver needs?</p>
                <div class="quiz" id="quiz-coff-string-table-2">
                    <button class="quiz-option" data-correct="true" data-explain="Section names use a third convention, distinct from the symbol union: a leading 0x2f slash followed by ASCII decimal digits giving an offset into the string table. So a resolver needs three rules, not two - inline name, slash-plus-decimal, and the symbol zero-dword form. The digits are also ASCII text, not a binary integer, which is why naive byte handling truncates them." onclick="checkQuiz('quiz-coff-string-table-2', this)">A section name uses a different rule from a symbol name: a leading <code>0x2f</code> means &ldquo;the rest of the field is an ASCII decimal offset into the string table&rdquo;. You need three cases &mdash; inline name, slash-and-decimal, and the symbol&rsquo;s zero-dword form &mdash; and the digits must be parsed as text, not bytes</button>
                    <button class="quiz-option" data-correct="false" data-explain="A non-zero first dword does mean the name is inline for a *symbol*. But section names are not a union with the symbol name field - they have their own convention, and it is the one being violated here. The first dword of /17 is 0x37312f2e, not zero, so the inline rule fires and the slash is discarded as if it were padding." onclick="checkQuiz('quiz-coff-string-table-2', this)">The reader is right about the union, but it must also handle the case where the name is stored inline yet contains a slash, and a resolver cannot tell those apart from the field alone</button>
                    <button class="quiz-option" data-correct="false" data-explain="The slash-plus-decimal form is genuinely the correct interpretation, so the conclusion is right. But the fix is not to use a different rule set - it is that the reader must also know where the string table is, and that location is derived by arithmetic from the symbol table pointer rather than stored in a field." onclick="checkQuiz('quiz-coff-string-table-2', this)">The name really is in the string table, so the resolver needs no change beyond looking up offsets starting at 4</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a format reuses one eight-byte slot for several kinds of value, the discriminator is a convention, not always a field. Write the three cases down explicitly, or you will ship a resolver that works on every name except the interesting ones.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Offset-not-content string pools are the same idea as DWARF's <code>DW_FORM_strp</code> and <code>DW_FORM_line_strp</code> in the <a href="/courses/dwarf/lessons/dwarf-file-tables">DWARF file tables</a> concept &mdash; one copy of each name, referenced by number, so the linker can merge identical pools across object files. That is why <code>.debug_str</code> is flagged <code>SHF_MERGE</code> in ELF and why the COFF string table is a prime candidate for the same treatment.</p>
                <p>The 8-byte inline-or-offset union is also how ELF's <code>sh_name</code> works in spirit, though ELF uses a 4-byte index into a dedicated string table rather than overloading one field. COFF's approach is older and more economical on space, at the cost of the three-way ambiguity you just hit.</p>
                <p>Now that names can be resolved, the table they belong to can be read. Module 2 continues with the structure that uses them most.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-symbol-table">The Symbol Table</a> &mdash; 18 bytes a record, and an aux record whose field order is not what the specification says.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-characteristics">Previous: Section Characteristics</a></span>
                <span><a href="/courses/coff/lessons/coff-symbol-table">Next: The Symbol Table</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
