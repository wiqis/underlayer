// COFF Course — Module 1: The Relocatable Object
// Concept: section characteristics, and the alignment bit-field trap.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_characteristics() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Section Characteristics — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>Section Characteristics</h1>
            <div class="lesson-meta">17 min &middot; Module 1: The Relocatable Object &middot; Bitfields</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The last four bytes of every section header is a 32-bit field that decides how the linker treats that section: is it code, is it writable, must it be executable, can it be thrown away. It is also the field most often mis-decoded, because part of it is a set of independent flags and part of it is a <em>four-bit number</em> that only looks like a flag.</p>
                <p>Getting that wrong does not produce a crash. It produces a tool that reports a section as having seven different alignments at once, and an alignment that appears in no list of valid values.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Split the 32 bits into three regions, because they obey three different rules:</p>
                <ol>
                    <li><strong>Bits 0&ndash;3 and scattered high bits</strong> &mdash; ordinary independent flags. Test each one, name it, move on.</li>
                    <li><strong>Bits 20&ndash;23</strong> &mdash; a single four-bit <em>field</em> holding a number from 0 to 15. Exactly one alignment applies.</li>
                    <li><strong>Bits 31&ndash;28</strong> &mdash; the memory permission bits, which happen to be three separate flags stacked at the top.</li>
                </ol>
                <p>The mental model that keeps this straight: a value of 5 in a four-bit field is the <em>binary number 0101</em>, not "flag 0 and flag 2". Testing the field against fifteen named constants is the correct approach; testing each of those constants as a bitmask is not.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Take <code>.text</code>'s real value, 0x60500020, and take it apart:</p>
                <div class="hex-dump">
                    <pre>0x60500020  =  0110 0000 0101 0000 0000 0000 0010 0000
                 |           |           |           |
                 |           |           |           +-- bit 5:  CNT_CODE
                 |           |           +-- bits 20-23: 0101 = 5 = ALIGN_16BYTES
                 |           +-- bit 30: MEM_READ
                 +-- bit 29: MEM_EXECUTE</pre>
                </div>
                <table>
                    <thead>
                        <tr><th scope="col">Mask</th><th scope="col">Name</th><th scope="col">Test</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x00000020</td><td><code>IMAGE_SCN_CNT_CODE</code></td><td>flag &mdash; test with <code>&amp;</code></td></tr>
                        <tr><td>0x00000040</td><td><code>IMAGE_SCN_CNT_INITIALIZED_DATA</code></td><td>flag</td></tr>
                        <tr><td>0x00000080</td><td><code>IMAGE_SCN_CNT_UNINITIALIZED_DATA</code></td><td>flag</td></tr>
                        <tr><td>0x00001000</td><td><code>IMAGE_SCN_LNK_COMDAT</code></td><td>flag</td></tr>
                        <tr><td>0x00000800</td><td><code>IMAGE_SCN_LNK_REMOVE</code></td><td>flag</td></tr>
                        <tr><td>0x02000000</td><td><code>IMAGE_SCN_MEM_DISCARDABLE</code></td><td>flag</td></tr>
                        <tr><td>0x20000000</td><td><code>IMAGE_SCN_MEM_EXECUTE</code></td><td>flag</td></tr>
                        <tr><td>0x40000000</td><td><code>IMAGE_SCN_MEM_READ</code></td><td>flag</td></tr>
                        <tr><td>0x80000000</td><td><code>IMAGE_SCN_MEM_WRITE</code></td><td>flag</td></tr>
                        <tr><td>0x00F00000</td><td><code>IMAGE_SCN_ALIGN_*</code></td><td><strong>field &mdash; shift, then compare</strong></td></tr>
                    </tbody>
                </table>
                <p>And here is the trap, stated as the exact bug it produces. <code>0x60500020</code> has the value 5 in the alignment field. A decoder written as a list of bitmask tests does this:</p>
                <div class="formula">
ALIGN_1BYTES   0x00100000   0x60500020 &amp; 0x00100000 = 0x00100000  -&gt; reports 1-byte<br>
ALIGN_2BYTES   0x00200000   0x60500020 &amp; 0x00200000 = 0x00000000  -&gt; no<br>
ALIGN_4BYTES   0x00300000   0x60500020 &amp; 0x00300000 = 0x00100000  -&gt; reports 4-byte<br>
ALIGN_8BYTES   0x00400000   0x60500020 &amp; 0x00400000 = 0x00400000  -&gt; reports 8-byte<br>
ALIGN_16BYTES  0x00500000   0x60500020 &amp; 0x00500000 = 0x00500000  -&gt; reports 16-byte<br>
ALIGN_32BYTES  0x00600000   0x60500020 &amp; 0x00600000 = 0x00400000  -&gt; reports 32-byte<br>
ALIGN_64BYTES  0x00700000   0x60500020 &amp; 0x00700000 = 0x00500000  -&gt; reports 64-byte
                </div>
                <p>Seven alignments reported, where the file has one. The correct decode is a shift and a compare against a lookup:</p>
                <div class="formula">
align = (Characteristics &gt;&gt; 20) &amp; 0xF        // = 5<br>
// 5 = IMAGE_SCN_ALIGN_16BYTES.  One answer.
                </div>
                <p>This was not a hypothetical. It is the first thing that went wrong when the independent parser for this course was written, and the reason the parser now masks the field explicitly rather than relying on its own flag list.</p>
                <p>Why is a field, and not a flag? Because alignment values are <em>ordinal</em>, not independent. 1-byte, 2-byte, 4-byte, 8-byte and 16-byte are increasing amounts of the same thing, so the format stores "how many steps up the ladder" rather than five separate yes/no bits. Four bits leaves room for 16 steps, which covers 1 byte up to 8 KB.</p>
                <h3>Every section in the reference object</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Value</th><th scope="col">align</th><th scope="col">Flags <code>llvm-readobj</code> prints</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>.text</code></td><td>0x60500020</td><td>5</td><td>CNT_CODE, ALIGN_16BYTES, MEM_EXECUTE, MEM_READ</td></tr>
                        <tr><td><code>.data</code></td><td>0xC0500040</td><td>5</td><td>CNT_INITIALIZED_DATA, ALIGN_16BYTES, MEM_READ, MEM_WRITE</td></tr>
                        <tr><td><code>.bss</code></td><td>0xC0300080</td><td>3</td><td>CNT_UNINITIALIZED_DATA, ALIGN_4BYTES, MEM_READ, MEM_WRITE</td></tr>
                        <tr><td><code>.xdata</code></td><td>0x40300040</td><td>3</td><td>CNT_INITIALIZED_DATA, ALIGN_4BYTES, MEM_READ</td></tr>
                        <tr><td><code>.rdata</code></td><td>0x40100040</td><td>1</td><td>CNT_INITIALIZED_DATA, ALIGN_1BYTES, MEM_READ</td></tr>
                        <tr><td><code>.rdata</code> (COMDAT)</td><td>0x40101040</td><td>1</td><td>CNT_INITIALIZED_DATA, <strong>LNK_COMDAT</strong>, ALIGN_1BYTES, MEM_READ</td></tr>
                        <tr><td><code>.debug$S</code></td><td>0x42300040</td><td>3</td><td>CNT_INITIALIZED_DATA, ALIGN_4BYTES, <strong>MEM_DISCARDABLE</strong>, MEM_READ</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x40300040</td><td>3</td><td>CNT_INITIALIZED_DATA, ALIGN_4BYTES, MEM_READ</td></tr>
                        <tr><td><code>.llvm_addrsig</code></td><td>0x00100800</td><td>1</td><td><strong>LNK_REMOVE</strong>, ALIGN_1BYTES</td></tr>
                    </tbody>
                </table>
                <p>Read that table as the linker's instruction sheet. Code is executable and read-only. <code>.data</code> is writable. <code>.bss</code> is writable and uninitialised. <code>.debug$S</code> is discardable, which means the linker throws it away unless debug information is requested &mdash; the mechanism behind a debug build's size. <code>.llvm_addrsig</code> is marked remove because it is metadata for the linker, not content for the program.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here are the characteristic fields as they actually sit in the file, at the last four bytes of each section header:</p>
                <div class="hex-dump">
                    <pre>.text  hdr 0x14, chars at 0x38:  20 00 50 60   -&gt; 0x60500020  align 5
.data  hdr 0x3c, chars at 0x60:  40 00 50 c0   -&gt; 0xc0500040  align 5
.bss   hdr 0x64, chars at 0x88:  80 00 30 c0   -&gt; 0xc0300080  align 3
.xdata hdr 0x8c, chars at 0xb0:  40 00 30 40   -&gt; 0x40300040  align 3
.rdata hdr 0xb4, chars at 0xd8:  40 00 10 40   -&gt; 0x40100040  align 1
.rdata hdr 0xdc, chars at 0x100: 40 00 10 40   -&gt; 0x40101040  align 1  (COMDAT)
.debug$S hdr 0x104, chars 0x128:  40 00 30 42   -&gt; 0x42300040  align 3  (discardable)</pre>
                </div>
                <p>Compare the third and sixth lines. Both are <code>.rdata</code>, and they differ by exactly one bit:</p>
                <div class="hex-dump">
                    <pre>plain   .rdata:  40 00 10 40     0x40100040
COMDAT  .rdata:  40 00 10 40     0x40101040
                                ^^^^^^^
                          0x1000 = IMAGE_SCN_LNK_COMDAT</pre>
                </div>
                <p>Nothing about the two sections' contents differs in the header. They are both read-only initialised data with 1-byte alignment. The <code>LNK_COMDAT</code> bit is the linker's instruction that this section is a candidate for deduplication, and the detail of <em>how</em> to deduplicate it lives in the symbol table, in the aux record's <code>Selection</code> and <code>CheckSum</code> fields. That is the subject of <a href="/courses/coff/lessons/coff-comdat">the COMDAT concept</a>.</p>
                <p>One more check that the decode is right, and it is the same kind of self-consistency test used for the file header. The <code>.text</code> section's first instruction is a <code>push rax</code> (<code>50</code>) at file offset 0x17C, and <code>.text</code> is marked <code>MEM_EXECUTE | MEM_READ</code> with no <code>MEM_WRITE</code>. A writable code section would be a red flag to every platform's security model; here the flags and the bytes agree, which is what you would expect from a compiler that got it right.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=x86_64-pc-windows-msvc -c sample.c -o sample_msvc.obj
$ llvm-readobj --sections sample_msvc.obj
$ xxd -s 0x38 -l 4 sample_msvc.obj</code></pre>
                <p>Then reproduce the bug deliberately, because seeing it happen is the point. Decode <code>0x60500020</code> both ways in any language:</p>
                <pre><code>// WRONG: treats alignment as a set of flags
for name, mask in [("1B",0x00100000),("2B",0x00200000),("4B",0x00300000),
                   ("8B",0x00400000),("16B",0x00500000),("32B",0x00600000)]:
    if 0x60500020 &amp; mask == mask: print("reports", name)

// RIGHT: treats it as a field
print("align =", (0x60500020 &gt;&gt; 20) &amp; 0xF, "= 16 bytes")</code></pre>
                <p>What to look for: the wrong version prints several alignments for one section, the right version prints one. Then check <code>llvm-readobj</code>'s output against the right version &mdash; it prints exactly one alignment per section, and it agrees.</p>
                <p>Worth noticing: <code>llvm-readobj</code> prints the flags <em>and</em> the raw value in parentheses, e.g. <code>Characteristics [ (0x60500020)</code>. Reading both the number and the names is the fastest way to catch a decode bug, because a value and its flag list that do not correspond is immediately visible.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a section header has <code>Characteristics = 0x40300040</code>. Which four flags does it carry, and what is its alignment?</p>
                <div class="quiz" id="quiz-coff-characteristics-1">
                    <button class="quiz-option" data-correct="true" data-explain="0x40300040 decomposes as 0x40000000 (MEM_READ) + 0x00300000 (alignment field = 3) + 0x40 (CNT_INITIALIZED_DATA). Alignment 3 is ALIGN_4BYTES. No MEM_EXECUTE and no MEM_WRITE. This is .xdata, the exception-unwinding table, which is read-only initialised data needing 4-byte alignment for its 4-byte fields." onclick="checkQuiz('quiz-coff-characteristics-1', this)">Read-only initialised data, alignment 3 = <code>ALIGN_4BYTES</code>, and no execute or write bit. This is <code>.xdata</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="MEM_EXECUTE is 0x20000000, and 0x40300040 does not contain it - 0x40000000 is MEM_READ. If this section were executable it would be code, but it carries CNT_INITIALIZED_DATA and no MEM_EXECUTE bit." onclick="checkQuiz('quiz-coff-characteristics-1', this)">It is executable, read-only initialised data, align 3 = <code>ALIGN_4BYTES</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="MEM_WRITE is 0x80000000, which is the top bit. 0x40300040 has bits 30 and 5 set, not bit 31. A writable section here would be .data, whose value is 0xc0500040." onclick="checkQuiz('quiz-coff-characteristics-1', this)">It is writable, uninitialised data, align 3 = <code>ALIGN_4BYTES</code></button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are auditing a build and want to flag any section that will end up writable <em>and</em> executable in the linked image, because that combination is what modern exploit mitigations look for. You have written the test as a pair of bitmask checks. What is wrong with your approach, and what does the audit actually have to do?</p>
                <div class="quiz" id="quiz-coff-characteristics-2">
                    <button class="quiz-option" data-correct="true" data-explain="The W^X check itself is fine - those are genuine independent flags and the bitmask test is correct for them. What is missing is that the audit is reading an object, where these are the linker's instructions, not the final permissions. A section's flags here can be widened at link time, and a linker also synthesises sections and merges COMDATs. To report final permissions the tool has to link the object, or state clearly that it is reporting intent rather than outcome." onclick="checkQuiz('quiz-coff-characteristics-2', this)">The W^X bitmask test is correct, but reading it from an object reports the linker&rsquo;s <em>intent</em>, not the final permissions. You must link the object and audit the image&rsquo;s section table, because the linker can change these flags</button>
                    <button class="quiz-option" data-correct="false" data-explain="MEM_WRITE (0x80000000) and MEM_EXECUTE (0x20000000) are independent bits in independent positions, and the bitmask test is exactly right for them. Nothing about a bitmask is wrong here; the problem is which file you are reading and what the values mean in it." onclick="checkQuiz('quiz-coff-characteristics-2', this)">Using bitmask tests is wrong because these are bit fields, not flags, so you need to shift and mask instead</button>
                    <button class="quiz-option" data-correct="false" data-explain="That is a real concern but it is a linker policy question, not a flag-decoding one. The decode is deterministic - the same value always yields the same flags - and a tool cannot detect that the linker will second-guess them without linking." onclick="checkQuiz('quiz-coff-characteristics-2', this)">The bitmask test is correct but unreliable, because a compiler may set contradictory flags that the linker will silently fix</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: know which of a field&rsquo;s bits are flags and which are numbers, and use the right test for each. But also know that decoding a file correctly and interpreting it correctly are separate skills &mdash; a perfectly decoded object header still does not tell you what the final executable will look like.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>These same permission bits appear in the PE section headers, where they <em>do</em> describe the running image &mdash; see <a href="/courses/pe/lessons/pe-common-sections">PE common sections</a> and <a href="/courses/pe/lessons/pe-security-flags">PE security flags</a>. The <a href="/courses/elf/lessons/common-sections">ELF course</a> has the same idea under a different name, with <code>SHF_WRITE</code> and <code>SHF_EXECINSTR</code> in <code>sh_flags</code>. Three formats, one question: may this page be written, and may it be executed?</p>
                <p>That closes Module 1. You have the container: a 20-byte header that says what kind of file this is, 40-byte section headers that say where the pieces are, and a characteristics field that says what the linker should do with them.</p>
                <p>Module 2 opens the tables that make an object <em>relocatable</em> &mdash; starting with the simplest one, the string pool that every other name is resolved through.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-string-table">The String Table</a> &mdash; eight bytes, two meanings, and one place where the format quietly runs out.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-section-table">Previous: The Section Header</a></span>
                <span><a href="/courses/coff/lessons/coff-string-table">Next: The String Table</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
