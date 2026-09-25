// COFF Course — Module 3: Containers and Variants
// Concept: the two section-header fields that are always zero, and what they are for.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_line_numbers() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Line Numbers — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>Line Numbers</h1>
            <div class="lesson-meta">16 min &middot; Module 3: Containers and Variants &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every section header you decoded in Module 1 had ten fields, and eight of them had a non-zero value. Two did not: <code>PointerToLinenumbers</code> and <code>NumberOfLinenumbers</code>, both zero in every section of every object in this course.</p>
                <p>That is not an oversight and it is not dead weight. COFF has native support for mapping code addresses to source lines &mdash; it was one of the format's original features, decades before DWARF existed &mdash; and this course is built on a toolchain that does not use it. Knowing which fields a compiler leaves alone, and why, is the difference between reading a format and guessing at it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>COFF's line-number support is the simplest possible design, and it is worth contrasting with what came later.</p>
                <p>A section header points at a table of <strong>6-byte records</strong>, each a pair:</p>
                <div class="formula">
offset  size  field
  0      4    SymbolTableIndex   which symbol in the section's symbol table
  4      2    LineNumber         the line, in the units defined below
                </div>
                <p>The table ends with a record whose two fields are both zero. That is the entire format: a sorted list of (symbol, line) pairs, and <code>LineNumber</code> is <strong>monotonically increasing</strong> within a symbol's run. There is no address in the table at all &mdash; the address comes from the symbol, and the symbol's <code>Value</code> is an offset within the section, exactly as in <a href="/courses/coff/lessons/coff-symbol-table">the symbol table concept</a>.</p>
                <p>Three properties follow, and they are why the design is so small:</p>
                <ul>
                    <li><strong>No address per row.</strong> The row says &ldquo;symbol 14, line 120&rdquo;, and the reader computes the address from the symbol. One 4-byte field saved per row.</li>
                    <li><strong>No file or column.</strong> A whole <code>.c</code> file is one table; the file is implied by the object. There is nowhere to put a path, let alone a column number.</li>
                    <li><strong>No expression evaluation.</strong> The line number is a plain integer, not a location expression as in DWARF. Nothing can be &ldquo;optimised out&rdquo; into a register.</li>
                </ul>
                <div class="callout callout-warn">
                    <strong>Why that last point is a problem, not a simplification.</strong> A plain <code>(symbol, line)</code> pair assumes code is laid out in source order, which is true at <code>-O0</code> and false the moment a compiler reorders, interleaves or inlines. An optimiser that hoists a loop, merges two functions or lays out a cold block separately cannot express that with these records, because the format has nowhere to say &ldquo;this line moved&rdquo;. COFF line numbers work for a debug build and have no way to work for an optimised one &mdash; which is precisely the gap DWARF was designed to close, with a state machine, a location list per variable, and a line program that can describe code in any order.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>What the compiler actually does</h3>
                <p>Every section of the reference object, from <code>llvm-readobj</code>:</p>
                <pre><code>$ llvm-readobj --sections sample_msvc.obj | grep -E 'Name:|LineNumberCount'
    Name: .text            LineNumberCount: 0
    Name: .data            LineNumberCount: 0
    Name: .bss             LineNumberCount: 0
    Name: .xdata           LineNumberCount: 0
    Name: .rdata           LineNumberCount: 0
    Name: .rdata           LineNumberCount: 0
    Name: .debug$S         LineNumberCount: 0
    Name: .pdata           LineNumberCount: 0
    Name: .llvm_addrsig    LineNumberCount: 0</code></pre>
                <p>Nine sections, nine zeros. And it is not that clang lacks the feature: the same objects carry a <code>.debug$S</code> section holding CodeView debug data, and <code>llvm-objdump</code> can disassemble <code>.text</code> with line annotations. <strong>clang simply does not write COFF line numbers</strong> &mdash; it writes CodeView records into a section that the COFF section header has no field for, which is a different mechanism entirely.</p>
                <p>The same is true of the GNU dialect. The i386 build, same source, same answer.</p>
                <h3>Verifying the field layout anyway</h3>
                <p>A field that is always zero cannot be verified by reading it, so the layout was verified by <strong>construction</strong>. A line-number table was appended to a real object and the section header patched to point at it:</p>
                <pre><code>$ python3 -c "
import struct, shutil
shutil.copy('sample_msvc.obj','lineno.obj')
d = bytearray(open('lineno.obj','rb').read())
entries = [(0,0x1000), (1,3), (0,0x2000), (1,4), (0,0)]
tbl = b''.join(struct.pack('&lt;IH', s, l) for s, l in entries)
linptr = len(d)
d += tbl
struct.pack_into('&lt;I', d, 0x14 + 28, linptr)   # PointerToLinenumbers
struct.pack_into('&lt;H', d, 0x14 + 34, len(entries))  # NumberOfLinenumbers
open('lineno.obj','wb').write(d)
print('appended at 0x%x, %d entries, %d bytes' % (linptr, len(entries), len(tbl)))
"
$ llvm-readobj --sections lineno.obj | head -12
    Number: 1
    Name: .text
    PointerToRelocations: 0x1E8
    PointerToLinenumbers: 0x5AF     &lt;- read back exactly what was written
    RelocationCount: 3
    LineNumberCount: 5</code></pre>
                <p>The reader reports <code>PointerToLinenumbers: 0x5AF</code> and <code>LineNumberCount: 5</code>, which is precisely what was written. That proves the two fields are where the specification says they are, and that the count is a record count rather than a byte count. It is shipped as <code>lineno.obj</code> alongside the other samples.</p>
                <div class="callout callout-warn">
                    <strong>What that does and does not prove.</strong> It proves the <em>field offsets</em>, because an independent reader found the values at the positions the specification predicts. It proves nothing about what the line numbers <em>mean</em>, and the temptation to teach a semantics here is exactly the mistake this course keeps documenting elsewhere &mdash; the <a href="/courses/coff/lessons/coff-relocations">relocation layout</a> that the specification documents and the compiler does not emit, the <a href="/courses/dwarf/lessons/dwarf-dies">DWARF <code>high_pc</code> form</a> that turns an address into a length. So: the layout is verified and taught; the semantics are not, and are not taught.
                </div>
                <h3>Why the values would not mean much anyway</h3>
                <p>This is the part worth understanding, because it explains a design that looks like an oversight.</p>
                <p>In a COFF object, <code>LineNumber</code> cannot be a source line number in any useful sense. Consider what a debugger would have to do with the table above: symbol 0, line 0x1000 &mdash; 4096. Line 4096 of a 30-line file? The value is an <strong>ordinal into a line-number program that lives in the debug information</strong>, and that program is produced during the link, when the real source line for each address is finally known. In a standalone object the referent does not exist.</p>
                <p>You can watch this go wrong. Disassemble the constructed file with line annotations enabled:</p>
                <pre><code>$ llvm-objdump -l --section=.text lineno.obj
0000000000000000 &lt;add&gt;:
; add():
       0: 50        pushq %rax
; g_ptr():
       8: 8b 04 24  movl (%rsp), %eax
; g_addr():
      10: c3        retq</code></pre>
                <p>The annotations name <code>add</code>, <code>g_ptr</code> and <code>g_addr</code> &mdash; functions that have nothing to do with the invented numbers, attached to instructions that are all from one function. The disassembler is resolving the ordinals against whatever symbol data it can find, and the result is confident, plausible, and meaningless. <strong>That output is the best possible argument for the discipline this course follows</strong>: a field whose meaning you cannot verify should not be taught, and a value that decodes without complaint is not thereby a value you understand.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What the table looks like when it <em>is</em> meaningful, so the shape is clear. Suppose an unoptimised build emitted this for <code>.text</code>:</p>
                <div class="hex-dump">
                    <pre>SymbolTableIndex  LineNumber        what it means
------------------  ---------------   ----------------------------
       20             3                symbol 20 = add(),  line 3
       20             4                ...still add(),  line 4
       20             5
       20             6
       21            11                symbol 21 = call_through(), line 11
       21            12
      ...
        0             0                the terminator: both fields zero</pre>
                </div>
                <p>And how a reader turns an address back into a line with it:</p>
                <ol>
                    <li><strong>Find the symbol.</strong> Given address <code>A</code> within section <code>S</code>, scan the section's symbols for the one whose <code>Value</code> is the greatest value not exceeding <code>A - S.base</code>. That is symbol 20.</li>
                    <li><strong>Scan the table for that symbol's run.</strong> The rows with <code>SymbolTableIndex == 20</code>.</li>
                    <li><strong>Take the last row whose line value is not greater than the one you want.</strong> Because the values increase within a run, the table is effectively sorted per symbol and can be scanned or binary-searched within the run.</li>
                    <li><strong>Report that line.</strong> There is no address to check, no file to name and no column to give, because the table has nowhere to put any of them.</li>
                </ol>
                <p>Compare that with the <a href="/courses/dwarf/lessons/dwarf-address-to-line">DWARF line number program</a>, which does the same job and additionally stores the file, the column, a discriminator for macro expansions, a basic-block flag, and an explicit end-of-sequence marker per function. DWARF also handles the case COFF cannot express at all: code that is not in source order. The COFF table has three fields; the DWARF program is a state machine with a dozen opcodes, and the difference in size is the difference between a format that can only describe a debug build and one that can describe any build.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ llvm-readobj --sections sample_msvc.obj | grep -c 'LineNumberCount: 0'
$ llvm-readobj --sections sample_gnu.obj  | grep -c 'LineNumberCount: 0'
$ llvm-readobj --sections sample_m32.obj  | grep -c 'LineNumberCount: 0'</code></pre>
                <p>All three should report every section, in all three dialects. Then confirm the fields are real rather than vestigial:</p>
                <pre><code>$ python3 -c "
import struct, shutil
shutil.copy('sample_msvc.obj','lineno.obj')
d = bytearray(open('lineno.obj','rb').read())
entries = [(0,0x1000), (1,3), (0,0x2000), (1,4), (0,0)]
tbl = b''.join(struct.pack('&lt;IH', s, l) for s, l in entries)
linptr = len(d); d += tbl
struct.pack_into('&lt;I', d, 0x14 + 28, linptr)
struct.pack_into('&lt;H', d, 0x14 + 34, len(entries))
open('lineno.obj','wb').write(d)
"
$ llvm-readobj --sections lineno.obj | grep -E 'PointerToLinenumbers|LineNumberCount'
$ llvm-objdump -l --section=.text lineno.obj | head</code></pre>
                <p>Three checks, in order of value:</p>
                <ul>
                    <li><strong>The two fields read back exactly what you wrote.</strong> That is the layout verification, and it is the reason the field positions in <a href="/courses/coff/lessons/coff-section-table">the section header concept</a> can be trusted for these two slots as well as the other eight.</li>
                    <li><strong>Change the count without changing the data</strong> and the reader reports the number you set, confirming it is a record count and not a byte count. Set it to 5 while the table has five records, then to 4, and watch it follow.</li>
                    <li><strong>Read the <code>-l</code> output critically.</strong> The function names it prints are invented, and that is the point. A tool that reports a line number without complaining is not thereby right, and this is the smallest possible demonstration of it.</li>
                </ul>
                <p>And the negative experiment worth doing: look for a compiler that <em>does</em> emit COFF line numbers, if you have MSVC's <code>cl.exe</code> to hand. <code>cl /Zi</code> writes CodeView data; the COFF-native tables are what you get from other toolchains. Confirming which of the two a given compiler writes is a more useful habit than memorising either layout.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you are writing a tool that lists the source lines covered by a COFF object. Every section reports <code>NumberOfLinenumbers: 0</code>. What is the correct conclusion, and what must you not conclude?</p>
                <div class="quiz" id="quiz-coff-line-numbers-1">
                    <button class="quiz-option" data-correct="true" data-explain="A zero count means this producer did not write COFF line numbers, which is a fact about the toolchain rather than about the file's validity or about the format. The companion field PointerToLinenumbers being zero too is consistent with that. What you must not conclude is that the fields are vestigial or that the object has no debug information at all - the same object carries a .debug$S section of CodeView data, which is a different mechanism the COFF section header has no field for." onclick="checkQuiz('quiz-coff-line-numbers-1', this)">This toolchain does not write COFF line numbers. The fields are real and correctly located &mdash; but you may <em>not</em> conclude the format lacks the feature, or that the object has no debug information at all</button>
                    <button class="quiz-option" data-correct="false" data-explain="The fields are not vestigial: their positions were confirmed by construction, with a table appended and both fields patched, and an independent reader reported the values back exactly. A format can support a feature its dominant producer declines to use, and the way to tell the two apart is to construct a case rather than to reason about the zeros." onclick="checkQuiz('quiz-coff-line-numbers-1', this)">The fields are vestigial. They are present in the section header for historical reasons, no modern producer writes them, and the format has moved on to CodeView entirely</button>
                    <button class="quiz-option" data-correct="false" data-explain="The zeros are consistent across all nine sections and in all three dialects compiled here, so this is a producer choice rather than a per-section accident. And the same object is not free of debug information: it carries a .debug$S section, so concluding that would make a working tool report no debugging where some exists." onclick="checkQuiz('quiz-coff-line-numbers-1', this)">The object is malformed, because a section with a zero line-number count and a zero pointer is internally inconsistent</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your build tool wants to map a crash address to a source line for a COFF object, and gets plausible-looking but wrong answers. You have established that the objects report <code>NumberOfLinenumbers: 0</code> and that the only line information present is CodeView in <code>.debug$S</code>. What is actually going on, and what is the correct fix?</p>
                <div class="quiz" id="quiz-coff-line-numbers-2">
                    <button class="quiz-option" data-correct="true" data-explain="The LineNumber field is an ordinal into a line-number program that is produced at link time, so in a standalone object the referent does not exist and any value is as good as any other. A disassembler that resolves those ordinals against whatever symbol data it can find will emit confident, plausible annotations that refer to nothing - which is exactly the confusing output. The correct move is to stop reading COFF line numbers and read the CodeView data in .debug$S, or the DWARF if the producer emitted that instead." onclick="checkQuiz('quiz-coff-line-numbers-2', this)">The values are ordinals into a line-number program that does not exist until the object is linked, so a standalone object&rsquo;s line numbers cannot be resolved. Read the CodeView data in <code>.debug$S</code> instead, or use DWARF where available</button>
                    <button class="quiz-option" data-correct="false" data-explain="This accepts that the values are meaningless and then tries to repair them, which cannot work: there is no source file association in the object to map an ordinal back to, and the ordinals do not correspond to anything in the .c file. The problem is not that the mapping is missing but that the referent itself is absent." onclick="checkQuiz('quiz-coff-line-numbers-2', this)">The symbols are being resolved against the wrong table. Cross-check each <code>SymbolTableIndex</code> against the section&rsquo;s own symbols and the line numbers will come out right</button>
                    <button class="quiz-option" data-correct="false" data-explain="The terminator is a real rule and worth checking, but it cannot be what is happening here, because every section reports a count of zero and therefore has no table at all to walk. A missing table and a mis-walked table produce different symptoms, and only the first matches." onclick="checkQuiz('quiz-coff-line-numbers-2', this)">The terminator record is being missed. A table whose final all-zero pair is not detected runs on into the next section&rsquo;s data and produces exactly this kind of confident nonsense</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: before debugging a value, establish that the thing it refers to exists. A number that indexes into a program, a table, or a pool is not a value until the pool is in front of you &mdash; and a decoder that never checks will hand you plausible answers indefinitely.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the direct contrast the whole module has been building toward. The <a href="/courses/dwarf/lessons/dwarf-address-to-line">DWARF line number program</a> solves the same problem with a state machine, explicit file and column, a discriminator for macros, and per-function end-of-sequence markers &mdash; and it works on optimised builds, because a program can describe code in any order. COFF&rsquo;s three-field table can only describe code that is laid out in source order, which is why it works at <code>-O0</code> and has no way to work anywhere else.</p>
                <p>The same shape of trade-off runs through the COFF course: the <a href="/courses/coff/lessons/coff-relocations">relocation table</a> is ten bytes per record and cannot express an arbitrary computation, while DWARF&rsquo;s location expression is a small program that can. Both formats put a bound on how much a reader can describe, and in each case the answer to &ldquo;what happens when the compiler does something the format cannot express&rdquo; is the same: a new format, or a new mechanism. CodeView in <code>.debug$S</code> is the Windows answer to that question, and it is why a COFF section header has no field for it.</p>
                <p>That closes Module 3. The two working halves of COFF are complete &mdash; the container that says what the pieces are, and the tables that let a linker place them &mdash; along with the containers and variants that surround them.</p>
                <p>What is still specified in <code>courses/coff/research.md</code> and deliberately unwritten: linker map files, and the incremental-linking and LTCG machinery, neither of which can be produced or observed on this machine because there is no COFF linker installed. The landing page lists them without links rather than as 404s.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-archives">Previous: The .lib Archive</a></span>
                <span><a href="/courses/coff">Course home</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
