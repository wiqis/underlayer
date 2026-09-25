// COFF Course — Module 2: Symbols and Relocations
// Concept: COMDAT selection, checksums, associative COMDAT, and the dialects.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_comdat() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("COMDAT and Duplicate Sections — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>COMDAT and Duplicate Sections</h1>
            <div class="lesson-meta">19 min &middot; Module 2: Symbols and Relocations &middot; Linker Semantics</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Write the same <code>inline</code> function in a header, include that header in four source files, compile them separately, and link them. You now have four copies of the same function. Keep them all and you get four definitions of one symbol. Throw them away arbitrarily and you can discard the copy a relocation actually points at.</p>
                <p>COMDAT is the mechanism that resolves this, and it is a strange one: the answer is not a flag on the section but a <em>policy</em> recorded in the symbol table, plus a checksum that lets the linker tell "the same function" from "the same signature with a different body".</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two pieces of information, in two different tables, and both are needed:</p>
                <ol>
                    <li><strong>A bit in the section header</strong> &mdash; <code>IMAGE_SCN_LNK_COMDAT</code>, saying "this section is a deduplication candidate". Without it the linker will not even look.</li>
                    <li><strong>A policy in the symbol table's aux record</strong> &mdash; the <code>Selection</code> byte, saying <em>how</em> to choose between duplicates. Different policies answer different questions.</li>
                    <li><strong>A <code>CheckSum</code> in the same aux record</strong> &mdash; a hash of the section's contents, so the linker can tell an exact duplicate from a near miss.</li>
                </ol>
                <p>The model's limit, and it is a real one: the checksum identifies the contents but says nothing about <em>identity</em>. Two functions can be byte-identical and be genuinely different, and two can share a signature and differ in one instruction. COFF answers only the first question, and leaves the second to the storage classes and to the linker complaining.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The source that produces the situation naturally:</p>
                <pre><code>struct S &#123; int a, b; &#125;;
inline S make(int v) &#123; S s; s.a = v; s.b = v * 2; return s; &#125;
int f() &#123; S s = make(3); return s.a + s.b; &#125;
template&lt;class T&gt; T twice(T v) &#123; return v + v; &#125;
int g() &#123; return twice(21); &#125;</code></pre>
                <p>Compile it and count the sections:</p>
                <pre><code>$ clang++ --target=x86_64-pc-windows-msvc -c comdat.cpp -o comdat.obj
$ file comdat.obj
comdat.obj: x86-64 COFF object file, not stripped, 13 sections
$ llvm-objdump -h comdat.obj | head -18</code></pre>
                <p><strong>Thirteen sections, and <code>.text</code> appears three times.</strong> So does <code>.xdata</code>, and so does <code>.pdata</code>. Duplicate section names are perfectly legal in COFF &mdash; they are not a bug and not even unusual &mdash; and they are how COMDAT works:</p>
                <table>
                    <thead>
                        <tr><th scope="col">#</th><th scope="col">Name</th><th scope="col">Characteristics</th><th scope="col">COMDAT?</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1</td><td><code>.text</code></td><td>0x60500020</td><td>no</td></tr>
                        <tr><td>2</td><td><code>.data</code></td><td>0xC0300040</td><td>no</td></tr>
                        <tr><td>3</td><td><code>.bss</code></td><td>0xC0300080</td><td>no</td></tr>
                        <tr><td>4</td><td><code>.xdata</code></td><td>0x40300040</td><td>no</td></tr>
                        <tr><td>5</td><td><code>.text</code></td><td>0x60501020</td><td><strong>yes</strong></td></tr>
                        <tr><td>6</td><td><code>.text</code></td><td>0x60501020</td><td><strong>yes</strong></td></tr>
                        <tr><td>7</td><td><code>.debug$S</code></td><td>0x42300040</td><td>no</td></tr>
                        <tr><td>8</td><td><code>.pdata</code></td><td>0x40300040</td><td>no</td></tr>
                        <tr><td>9</td><td><code>.llvm_addrsig</code></td><td>0x00100800</td><td>no</td></tr>
                        <tr><td>10</td><td><code>.xdata</code></td><td>0x40301040</td><td><strong>yes</strong></td></tr>
                        <tr><td>11</td><td><code>.xdata</code></td><td>0x40301040</td><td><strong>yes</strong></td></tr>
                        <tr><td>12</td><td><code>.pdata</code></td><td>0x40301040</td><td><strong>yes</strong></td></tr>
                        <tr><td>13</td><td><code>.pdata</code></td><td>0x40301040</td><td><strong>yes</strong></td></tr>
                    </tbody>
                </table>
                <p>The COMDAT sections are the ones whose characteristics differ from their non-COMDAT namesake by exactly the <code>0x1000</code> bit. Compare section 4 and section 10, both <code>.xdata</code>:</p>
                <div class="hex-dump">
                    <pre>plain  .xdata:  40 00 30 40     0x40300040
COMDAT .xdata:  40 00 10 40     0x40301040
                              ^^^^^
                     0x1000 = IMAGE_SCN_LNK_COMDAT</pre>
                </div>
                <h3>The selection policies</h3>
                <p>Now the part that is not a flag. The <code>Selection</code> byte at offset 0x0e of the section's aux record tells the linker which duplicate to keep, and both values below occur naturally in this one object:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Value</th><th scope="col">Name</th><th scope="col">Rule</th><th scope="col">In <code>comdat.obj</code></th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td><code>NONE</code></td><td>not a COMDAT; keep it</td><td>every ordinary section</td></tr>
                        <tr><td>1</td><td><code>NODUPLICATES</code></td><td>error if a duplicate appears</td><td>not used</td></tr>
                        <tr><td>2</td><td><code>ANY</code></td><td>keep any one of them</td><td><strong>the two <code>.text</code> COMDATs</strong></td></tr>
                        <tr><td>3</td><td><code>SAME_SIZE</code></td><td>keep one, but all must be the same size</td><td>not used</td></tr>
                        <tr><td>4</td><td><code>EXACT_MATCH</code></td><td>keep one only if byte-identical</td><td>not used</td></tr>
                        <tr><td>5</td><td><code>ASSOCIATIVE</code></td><td>this section lives or dies with the others in its group</td><td><strong>the <code>.pdata</code> and <code>.xdata</code> COMDATs</strong></td></tr>
                    </tbody>
                </table>
                <p><code>ANY</code> is the one you will see most: the compiler has decided the bodies are equivalent, so the linker may keep whichever copy it likes. <code>ASSOCIATIVE</code> is subtler and more interesting, because the decision is not about this section at all &mdash; it is about a <em>group</em>.</p>
                <p>Here is the pairing, straight from the aux records. The <code>.pdata</code> COMDAT (section 12) has <code>Length 12, Selection 5, Number 5</code>, and the <code>.xdata</code> COMDAT that shares its <code>Number</code> (section 10) has <code>Length 8, Selection 5, Number 5</code>. The <code>Number</code> field is the group identifier. Two sections with the same number and <code>Selection = ASSOCIATIVE</code> are a unit: the linker keeps them together or discards them together.</p>
                <p>Why does that matter? Because an <code>.xdata</code> entry without its matching <code>.pdata</code> entry, or the reverse, is meaningless. A <code>.pdata</code> record says "this range of code unwinds using the unwind data at this address". Keep one half and the exception unwinder faults at runtime. Neither section is meaningful alone, so neither may be independently discarded &mdash; and <code>ASSOCIATIVE</code> is how the format says that.</p>
                <p>And the <code>CheckSum</code> is what makes the decision safe. The verified values from this object:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">CheckSum</th><th scope="col">Selection</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>5 <code>.text</code></td><td>0xEEE27D3D</td><td>ANY (2)</td></tr>
                        <tr><td>6 <code>.text</code></td><td>0x5127CE02</td><td>ANY (2)</td></tr>
                        <tr><td>10 <code>.xdata</code></td><td>0x63791761</td><td>ASSOCIATIVE (5)</td></tr>
                        <tr><td>11 <code>.xdata</code></td><td>0x1AB96B84</td><td>ASSOCIATIVE (5)</td></tr>
                        <tr><td>12 <code>.pdata</code></td><td>0x7D3C6CAC</td><td>ASSOCIATIVE (5)</td></tr>
                    </tbody>
                </table>
                <p>Note that sections 5 and 6 have <em>different</em> checksums. They are both named <code>.text</code>, both marked COMDAT, and both use <code>ANY</code> &mdash; but they are not the same bytes. That is correct and expected: they are two different functions, each with its own body, and the compiler emitted each in its own COMDAT section. The checksum is not what makes them duplicates; the <em>symbol names</em> do. Two COMDAT sections with the same name and the same checksum coming from two different object files are the same function, and one is discarded.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The same source, two dialects, and the difference is entirely about COMDAT:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Property</th><th scope="col">MSVC dialect</th><th scope="col">GNU dialect</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Sections</td><td>9</td><td><strong>8</strong></td></tr>
                        <tr><td><code>.rdata</code> count</td><td><strong>2</strong>, one COMDAT</td><td>1</td></tr>
                        <tr><td>String literal name</td><td><code>??_C@_03PLHFFLIH@ptr?$AA@</code></td><td>none &mdash; inlined or not emitted</td></tr>
                        <tr><td>Machine</td><td>0x8664</td><td>0x8664</td></tr>
                    </tbody>
                </table>
                <p>The MSVC build merged the two string literals in <code>sample.c</code> into a deduplicated COMDAT <code>.rdata</code>, which is why it has a second <code>.rdata</code> and a mangled symbol pointing into it. The GNU build did not, so it has one fewer section. Both files are valid COFF; both use the same 20- and 40-byte records. A reader cannot tell which dialect it has from the container, only from the contents &mdash; which is why <code>Machine</code> plus the type tables is the minimum a reader needs.</p>
                <p>And the i386 build, for the third data point:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Property</th><th scope="col">x64 MSVC</th><th scope="col">i386 MSVC</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Machine</td><td>0x8664</td><td><strong>0x014C</strong></td></tr>
                        <tr><td>Address size</td><td>64-bit</td><td><strong>32-bit</strong></td></tr>
                        <tr><td><code>add</code> symbol</td><td><code>add</code></td><td><strong><code>_add</code></strong></td></tr>
                        <tr><td>Relocation names</td><td><code>IMAGE_REL_AMD64_REL32</code></td><td><strong><code>IMAGE_REL_I386_DIR32</code></strong></td></tr>
                    </tbody>
                </table>
                <p>That leading underscore is the cdecl symbol decoration, which x64 removed because its calling convention passes the first four arguments in registers rather than on the stack. It is the smallest possible demonstration that a symbol name in a COFF file is a <em>linker</em> name, not a source name &mdash; and that it changes with the target, not with the code.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang++ --target=x86_64-pc-windows-msvc -c comdat.cpp -o comdat.obj
$ llvm-objdump -h comdat.obj
$ llvm-readobj --sections comdat.obj | grep -E 'Number:|Name:|LNK_COMDAT'
$ llvm-readobj --symbols comdat.obj | grep -B9 'Selection: [^0]' | head -40</code></pre>
                <p>What to look for, in order:</p>
                <ul>
                    <li><strong>Three sections named <code>.text</code>.</strong> Count them in <code>llvm-objdump -h</code> before reading anything else.</li>
                    <li><strong>Exactly the COMDAT ones carry the extra 0x1000.</strong> Diff each duplicate against its non-COMDAT namesake and the difference is one bit.</li>
                    <li><strong>Selection 2 and Selection 5 both appear.</strong> The <code>.text</code> duplicates use <code>ANY</code>; the <code>.pdata</code> and <code>.xdata</code> ones use <code>ASSOCIATIVE</code> and share a <code>Number</code>.</li>
                </ul>
                <p>To make the deduplication actually happen, compile the same function into two object files and link them:</p>
                <pre><code>$ cat a.cpp
inline int shared(int v) &#123; return v * 3; &#125;
int use_a() &#123; return shared(7); &#125;
$ cat b.cpp
inline int shared(int v) &#123; return v * 3; &#125;
int use_b() &#123; return shared(7); &#125;
$ clang++ --target=x86_64-pc-windows-msvc -c a.cpp -o a.obj
$ clang++ --target=x86_64-pc-windows-msvc -c b.cpp -o b.obj
$ llvm-readobj --symbols a.obj | grep -c 'Selection: 2'
$ llvm-readobj --symbols b.obj | grep -c 'Selection: 2'</code></pre>
                <p>Both objects contain a COMDAT copy of <code>shared</code>. That is the situation the mechanism exists for, and you have just created it in two files.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a COMDAT section has <code>Selection = 5</code> (ASSOCIATIVE) and <code>Number = 5</code>, and another COMDAT section has <code>Selection = 5</code> and <code>Number = 5</code> as well. What will the linker do with the pair, and why would keeping one of them be a bug?</p>
                <div class="quiz" id="quiz-coff-comdat-1">
                    <button class="quiz-option" data-correct="true" data-explain="Equal Number plus Selection 5 makes the two sections one group. The linker keeps both or discards both, because a .pdata entry without its .xdata entry points at unwind data that is not there, and the exception unwinder faults. Neither half means anything alone, which is exactly the situation ASSOCIATIVE exists to express - ANY would let the linker keep one and break the program." onclick="checkQuiz('quiz-coff-comdat-1', this)">It treats them as one group and keeps or discards both together. Keeping one would leave an exception-unwinding record pointing at unwind data that is no longer there, which faults at runtime rather than at link time</button>
                    <button class="quiz-option" data-correct="false" data-explain="Selection 5 does not mean 'any one will do'. It means the decision is not this section's to make: the sections are bound together, and the group survives or dies as a unit. That is the opposite of choosing arbitrarily." onclick="checkQuiz('quiz-coff-comdat-1', this)">It keeps whichever of the two has the matching checksum, since a matching checksum means the contents are identical</button>
                    <button class="quiz-option" data-correct="false" data-explain="That would be the rule if the two sections carried the same name as well, and it is how duplicate .text COMDATs are resolved. Here the shared Number is a group id, and Selection 5 gives it its meaning: the two must be kept or discarded together regardless of contents." onclick="checkQuiz('quiz-coff-comdat-1', this)">It keeps the first one it encounters and discards the second, because equal Numbers mean the sections are duplicates</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Two object files each contain a COMDAT section named <code>.text</code> with <code>Selection = ANY</code>, and their <code>CheckSum</code> values are <em>different</em>. Your linker discards one of them anyway, and a function ends up calling the wrong body. What has the linker done wrong, and what is the correct reading of that checksum difference?</p>
                <div class="quiz" id="quiz-coff-comdat-2">
                    <button class="quiz-option" data-correct="true" data-explain="A different checksum means the contents are not identical, and the linker resolved them by name, not by content. That is the compiler's assertion, under Selection ANY, that the two are interchangeable. When a build produces same-named ANY COMDATs with different checksums, the cause is usually a macro or inline function whose definition differs between the two translation units - a configuration flag, an <code>#ifdef</code>, or a mismatch in a header. The bug is in the source, and the fix is to make the definitions match." onclick="checkQuiz('quiz-coff-comdat-2', this)">It resolved by name rather than by content. Under <code>ANY</code> the compiler has asserted the bodies are interchangeable, so a checksum difference means the two <em>definitions were not the same</em> &mdash; usually a macro or <code>#ifdef</code> difference between the translation units. The bug is in the source, not the linker</button>
                    <button class="quiz-option" data-correct="false" data-explain="A checksum difference does mean the bytes differ, but it does not mean the two sections are unrelated. Under Selection ANY the compiler has already decided they may be interchanged; the checksum is there for the linker to detect exactly this kind of inconsistency, not to drive the choice of which to keep." onclick="checkQuiz('quiz-coff-comdat-2', this)">It should have raised an error instead of silently discarding a section, because a checksum mismatch under ANY means the compiler promised something false</button>
                    <button class="quiz-option" data-correct="false" data-explain="A checksum is a hash of section contents, not a stable identifier. Two byte-identical sections from two object files hash to the same value, which is what makes the comparison useful; it is not something that varies per file, so it cannot be used to tell sections apart." onclick="checkQuiz('quiz-coff-comdat-2', this)">The linker is right to discard one, because two sections with the same name are always duplicates regardless of their contents</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a checksum that differs when a format says the items should match is not noise. It is the mechanism working &mdash; it is telling you that an assumption made earlier upstream, in the source, has been violated.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>COMDAT is COFF's answer to a problem ELF solves differently, and the contrast is the point. ELF has no <code>SHF_COMDAT</code>; it has <code>.group</code> sections and <code>SHT_GROUP</code>, which group members explicitly and support associated metadata such as link-order hints. The <a href="/courses/elf/lessons/common-sections">ELF common sections</a> concept covers that mechanism. COFF's approach is lighter &mdash; a bit, a policy byte, and a checksum &mdash; which is why it works well for C++ inline functions and why it is the only COMDAT-like mechanism most Windows toolchains expose.</p>
                <p>The <code>CheckSum</code> field is the same instinct as DWARF's line-table checksums and as ELF's <code>SHF_MERGE</code> string sections: use a hash to decide whether two copies are the same, so you can merge or discard without a full comparison. The <a href="/courses/dwarf/lessons/dwarf-line-header">DWARF header concept</a> makes the same argument for a different table.</p>
                <p>That completes Module 2, and with it the format's two working halves: the container that says what the pieces are, and the tables that let a linker place them. What is deliberately <em>not</em> here is the other side of the same story.</p>
                <p>Coming next, and specified in <code>courses/coff/research.md</code> but not yet written: the <code>bigobj</code> variant, whose header <strong>relocates its fields</strong> rather than widening them &mdash; a naive two-byte patch produces a file that every tool rejects &mdash; the <code>.lib</code> archive container, linker map files, and the short-export format. The PE course already covers the import and export directories of a linked image, so those are cross-linked rather than repeated.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-relocations">Previous: Relocations</a></span>
                <span><a href="/courses/coff">Course home</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
