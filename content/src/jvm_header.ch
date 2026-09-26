// JVM Course — Module 1: The Container
// Concept: the header, the fixed order, and the fact that the pool is
// renumbered every time a name is added.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_header() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Header and the Fixed Order — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>The Header and the Fixed Order</h1>
            <div class="lesson-meta">18 min &middot; Module 1: The Container &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The class file has no section table. There is no list of blocks, no id byte telling you what follows, no index to build first. <strong>Every field is at a fixed position given the ones before it</strong>, and a reader walks the structure from the top knowing exactly what comes next at every step, all the way to the last byte.</p>
                <p>That is a genuinely unusual design and it has one dominant consequence: <strong>the file is parsed, never indexed.</strong> There is no random access. You cannot jump to the methods without walking the pool, the fields, and everything between, because the only way to find the methods is to count your way there. A format with a section table lets a reader do that in two steps; this one makes it one long step.</p>
                <p>The second consequence is less obvious and more annoying in practice. <strong>Adding a name renumbers the file.</strong> The constant pool is built in the order the compiler encounters things, so insert one string literal in the middle of a method and every entry after it moves. Nothing in the file refers to a name by position in a stable way, so any tool that caches a byte offset into a class file &mdash; a build system, an incremental compiler, a coverage tool &mdash; has to throw that cache away when the class changes at all.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The whole structure, with the sizes that are fixed and the ones that are not:</p>
                <div class="formula">
offset  size  field               fixed?
     0     4  magic                 yes, always CAFEBABE
     4     2  minor_version         no, but only 0 or 65535 exist
     6     2  major_version        no, pinned to the Java release
     8     2  constant_pool_count  no, but always pool_count = usable + 1
    10   ...  constant_pool         no, this is most of the file
   ...     2  access_flags          no, a bitfield
   ...     2  this_class            no, a pool index
   ...     2  super_class           no, a pool index, or 0
   ...     2  interfaces_count
   ...   2*n  interfaces            n pool indices
   ...     2  fields_count
   ...   ...  fields                variable, self-delimiting
   ...     2  methods_count
   ...   ...  methods               variable, self-delimiting
   ...     2  attributes_count
   ...   ...  attributes            variable, self-delimiting
</div>
                <p>Only the first eight bytes are at a known offset. Everything after the pool's count is a walk, and the walk works because <strong>every variable-length record states its own length</strong>:</p>
                <div class="formula">
member (field or method):
    access_flags           2 bytes
    name_index             2 bytes, into the pool
    descriptor_index       2 bytes, into the pool
    attributes_count       2 bytes
    attributes             attributes_count records

attribute:
    attribute_name_index   2 bytes, into the pool
    attribute_length       4 bytes  &lt;-- the escape hatch
    info                   exactly that many bytes
</div>
                <p>That <code>attribute_length</code> is the single most important field in the format after the magic, and it is worth understanding what it is for. <strong>It is the format's only extension mechanism.</strong> A reader that meets an attribute name it does not know skips <code>attribute_length</code> bytes and carries on &mdash; so the JVM can read a class file containing an attribute invented after the JVM shipped, and ignore it. A new <em>attribute</em> is therefore free and needs no version bump.</p>
                <p>What the length does <em>not</em> buy is a new top-level block. There is nowhere to put one, because the order is fixed and the reader has no way to skip a block it does not recognise. That is the bargain: <strong>attributes are open, the file is not.</strong> Java has shipped sealed classes, records and modules by adding attributes and, where the change was too big for that, by adding new attributes <em>and</em> bumping the major version &mdash; which is why the major version is the Java release number rather than a format counter that could have moved independently.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The 409-byte <code>Hello.class</code> from this course's samples, walked from the top. Every number below is from the file on disk, and the offsets are given so you can check them against a hex dump:</p>
                <div class="hex-dump">
                    <pre>  0x0000  4  magic              ca fe ba be
  0x0004  2  minor_version      00 00
  0x0006  2  major_version      00 46          = 70, Java 26
  0x0008  2  constant_pool_count 00 1d         = 29
  0x000a     the pool, 28 usable entries, ending at 0x0124
  0x0125  2  access_flags       00 21          ACC_PUBLIC ACC_SUPER
  0x0127  2  this_class         00 15          #21, which is "Hello"
  0x0129  2  super_class        00 02          #2, "java/lang/Object"
  0x012b  2  interfaces_count   00 00
  0x012d  2  fields_count       00 00
  0x012f  2  methods_count      00 02
  0x0131  ... two method records
  0x018f  2  attributes_count   00 01
  0x0191  ... SourceFile
  0x0199     end of file: exactly 409 bytes
</pre>
                </div>
                <p>Three things in that walk are worth stopping on.</p>
                <p><strong>The pool's count is one more than the number of entries.</strong> The file says 29 and there are 28 usable entries, because the pool is <strong>one-indexed</strong>: index 0 is reserved and never used, so a stored count of <em>n</em> means entries <code>1</code> through <code>n-1</code>. A reader that allocates <code>n</code> entries and loops to <code>n</code> will read one past the end, and a reader that treats index 0 as a valid entry &mdash; the way a C array naturally invites &mdash; will resolve a name to whatever happens to be at offset zero of the table.</p>
                <p><strong>Indices in the header are pool indices, and they are the pool's own numbering.</strong> <code>this_class</code> is <code>0x15</code> = 21, and entry 21 is a <code>CONSTANT_Class</code> pointing at entry 22, which is the <code>Utf8</code> <code>"Hello"</code>. So the class's own name is <em>two</em> indirections from the field that names it. There is no shortcut to a name anywhere in this format; everything goes through the pool, always.</p>
                <p>And <strong>the pool is most of the file.</strong> 28 entries occupy bytes 0x0a to 0x0124 &mdash; 283 bytes of 409, which is 69% of a hello-world. The code that actually does the work is 14 bytes across two methods. <strong>The ratio is the argument for the whole design</strong>: a format that names everything by index into one shared table pays for the table once and gets compression everywhere else, and on real code the table is where the bytes are.</p>
                <h3>What the version field is really for</h3>
                <p>Worth being precise, because the intuition is usually wrong in both directions. The major version is not incremented when the file format changes &mdash; it is <strong>the Java feature release that produced the file</strong>, and the format's own history is welded to it. Major 52 is Java 8 and introduced the <code>invokedynamic</code>-based lambda implementation; every major number since has been a Java release. So a class file's major version tells you two things at once: which features the class might use, and which JVM can run it.</p>
                <p>And the compatibility rule is absolute, not graded. A JVM reads the major version, checks it against what it implements, and if it is too new the class is refused before anything else is read. There is no partial support, no "I can run the methods but not the constant pool", and no attempt to read what it recognises. Compare <a href="/courses/elf/lessons/elf-identification">an ELF file with an unfamiliar machine type</a>, which a loader will usually attempt anyway, or a <a href="/courses/pe/lessons/pe-optional-header">PE file with an unfamiliar <code>Magic</code></a>, where the same is true.</p>
                <div class="callout callout-warn">
                    <strong>Why that hardness is a feature.</strong> A class file is not going to be concatenated, patched, or partially interpreted by something that only understands the old layout &mdash; there is no linker that could get it subtly wrong, and no loader that could guess. The hard boundary is what makes it safe for a machine to refuse in six bytes instead of attempting a load it cannot complete. <strong>Every other format in this collection is designed to be partially understood</strong>, which is more flexible and considerably harder to reason about, because a reader that half-works is worse than one that refuses. The class file gives up partial compatibility on purpose, and the minor version's entire job is to flag the one case where that would be inconvenient: a preview feature, marked by setting minor to <code>0xFFFF</code>, which is a promise that this file will only load in the exact JVM build that compiled it.
                </div>
                <h3>The renumbering problem</h3>
                <p>Here is the practical consequence, and it is worth seeing concretely rather than being told about. Take <code>Hello.class</code> and add one string literal to the middle of <code>main</code>. The compiler encounters the new string while walking the method, so it lands in the middle of the pool, and <strong>every entry after it moves up by one</strong>. The <code>Utf8</code> that was <code>#24</code> is now <code>#25</code>, and so is everything else.</p>
                <p>Nothing in the file is broken by this &mdash; every reference is updated consistently, because the compiler writes the file after it has finished building the pool. But it means <strong>the byte offset of any given name is not a property of the name</strong>. It is a property of this compilation of this source. Any tool that recorded "the string <code>hello</code> is at offset 0x1D4 in this class" has recorded something true only until the class is recompiled from anything but identical source. That is why incremental build systems keyed on class files are fragile, and why the tools that do it key on a hash of the content instead.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Reading the file to the last byte, which is the discipline that catches everything: after the walk, the cursor must be exactly at the end. Not past it, not short of it.</p>
                <div class="formula">
walk(path):

    p = 0
    assert read_u4(p) == 0xCAFEBABE      # the only sanity check available
    p = 8
    cp_count = read_u2(p);  p += 2

    # the pool is walked by ENTRY, not by byte count, because a Long or a
    # Double entry is longer than its tag suggests and consumes two indices
    i = 1
    while i &lt; cp_count:
        tag = read_u8(p);  p += 1
        p += payload_size(tag, p)       # varies: 2, 3, 4, 8, or u2+varying
        i += 1 if tag not in (Long, Double) else 2

    access = read_u2(p);  p += 2
    this_i = read_u2(p);  p += 2
    super_i = read_u2(p);  p += 2

    for _ in range(read_u2(p)):  p += 2      # interfaces
    for _ in range(read_u2(p)):  p = member(p)   # fields
    for _ in range(read_u2(p)):  p = member(p)   # methods
    p = attributes(p, read_u2(p))

    assert p == len(file), "trailing or missing bytes"
</div>
                <p>That final assertion is the one that earns its keep, and it is the same habit the WebAssembly course arrived at independently. <strong>A structural reader that does not check where it ended cannot distinguish a correct parse from a parse that lost sync two hundred bytes ago.</strong> The two produce the same output &mdash; plausible names, plausible indices &mdash; and the only difference is that one of them is wrong. An end-of-file assertion turns that class of bug from silent into loud, and it costs one comparison.</p>
                <p>It is worth being concrete about what desynchronisation looks like here, because this format makes it unusually easy. Every count in the header is a <code>u2</code>, so a reader that misjudges a length will read a number that is very often a plausible small integer. A method's <code>attributes_count</code> is typically 1 or 2. A misread that turns into 1 or 2 is <em>not</em> going to be noticed &mdash; the walk continues, reads two more six-byte attribute headers, and arrives at a position that is wrong by twelve bytes. The names it reports afterwards will still be pool indices, and most pool indices resolve, because a pool is large and most of its entries are strings.</p>
                <div class="callout callout-warn">
                    <strong>And the failure is invisible in the output.</strong> A decoder that has lost sync by a multiple of two will still report method names from the pool, because method names <em>are</em> pool indices and the pool does not care what they point at. The result reads perfectly: plausible names, plausible descriptors, a plausible method count. Nothing in the printed output distinguishes it from a correct parse. <strong>The end-of-file assertion is the only thing that does</strong>, which is why this course's decoder prints its final byte position on every file and why the crosscheck harness treats "did not consume the whole file" as a failure rather than a note. It is the same lesson as the <a href="/courses/wasm/lessons/wasm-code">run-length local declarations</a> in the WebAssembly course, arriving from a completely different format: in a binary format with a variable-length record, <em>the only reliable signal that you have gone wrong is that you ended up in the wrong place</em>.
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Hello.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Hello.class</code></pre>
                <ul>
                    <li><strong>Walk the file by hand and check the total.</strong> Header, pool, then the four counts, then the members, then the attributes. Add up the bytes and confirm you land exactly on 409. <strong>Do it once by hand and the format stops being abstract for good</strong> &mdash; every later concept is a variation on a walk you have already done.</li>
                    <li><strong>Prove the pool is 1-indexed.</strong> Find the reserved index 0 and work out what a reader that treats it as valid resolves to. Then read your own decoder and see how it refuses index 0. <strong>An off-by-one that produces a valid-looking name is the most expensive kind, and the fix is to check the boundary rather than trust the arithmetic.</strong></li>
                    <li><strong>Measure the pool's share of a real class.</strong> Compile something substantial and compare the pool's byte range to the file length. Then compile the same logic with fewer distinct string literals and watch the ratio move. <strong>The pool is a dictionary, and a dictionary pays off in proportion to how much the text repeats itself.</strong></li>
                    <li><strong>Demonstrate the renumbering.</strong> Compile a class, note a Utf8 index, add one unrelated name to the middle, recompile, and diff. <strong>Every index after the insertion point shifts by one, and nothing in the file was wrong at any point</strong> &mdash; which is what makes it a good thing to know before you build a cache on top of one.</li>
                    <li><strong>Break the end-of-file assertion on purpose.</strong> Change your decoder's <code>payload_size</code> for one tag so it is one byte short, and run it on a real class. Then fix it. <strong>Watch how much of the output still looks correct</strong> &mdash; that is the whole argument for the assertion, and it is much more convincing when you have seen it than when you have read it.</li>
                    <li><strong>Find an attribute your JVM does not know.</strong> Compile with a preview feature enabled, or use a recent JDK and a class built by an older one, and list the attribute names. Then find the specification's list and confirm which are new. <strong>Attributes are the format's open edge, and the version number is the closed one</strong> &mdash; understanding which is which tells you which Java features could have shipped without a version bump.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a class file's <code>constant_pool_count</code> is 29, and its <code>methods_count</code> is 2. How many usable constant pool entries are there, why is that number not 29, and what does a reader that allocates 29 slots and loops <code>i = 0; i &lt; 29</code> actually do?</p>
                <div class="quiz" id="quiz-jvm-header-1">
                    <button class="quiz-option" data-correct="true" data-explain="Twenty-eight usable entries, because the pool is one-indexed: index 0 is reserved, so a stored count of n means entries 1 through n-1. The loop is the interesting half. Starting at i=0, the reader resolves index 0, which is the reserved slot and should never appear in a valid file, so it gets whatever the table happens to hold there rather than a real constant. That name is then used as though it were meaningful, and because the pool is mostly Utf8 entries, the result is very likely a plausible-looking string. Then the loop's extra iteration at i=29 reads one past the end of the table entirely, which is a bounds error or a garbage entry depending on the implementation. So the bug produces two distinct wrong behaviours from one mistake: a bogus resolution at the start and an overrun at the end. The general rule is that a one-based table with a reserved zero needs the reserved slot checked explicitly, not merely skipped, because a reader that starts at zero is reading a slot the format guarantees is meaningless." onclick="checkQuiz('quiz-jvm-header-1', this)">Twenty-eight usable entries, because the pool is 1-indexed and index 0 is reserved. The loop resolves the reserved index 0, which yields a meaningless value, and then runs one iteration past the end of the table reading a slot that does not exist</button>
                    <button class="quiz-option" data-correct="false" data-explain="The count of 29 does mean 28 usable entries, so that half is right, but the consequence is wrong: a zero-based loop over 29 slots does not read one past the end of the data, it reads exactly the 28 usable entries plus the reserved slot 0. The overrun is not the problem here; the problem is the reserved slot. A reader that starts at index 0 resolves the entry the format guarantees is never valid, and since most pool entries are Utf8 the result is likely to be a plausible string rather than an obvious error. The overrun would come from looping to the stored count inclusively, i.e. i &lt;= 29, which is a different mistake with a different symptom." onclick="checkQuiz('quiz-jvm-header-1', this)">Twenty-eight usable entries, and the loop reads one past the end of the pool, which is where an out-of-bounds error would be reported</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your class file reader reports a plausible method count and a plausible list of method names for a 40&nbsp;KB class, and the names are real method names. The <code>Code</code> attributes it then decodes contain instruction bytes that disassemble to nothing sensible. The end-of-file assertion passes. Nothing else is wrong: the header, the pool and the member counts are all correct. What is the most likely defect, and why does the fact that the end-of-file assertion <em>passing</em> narrow it sharply?</p>
                <div class="quiz" id="quiz-jvm-header-2">
                    <button class="quiz-option" data-correct="true" data-explain="The end-of-file assertion passing is the discriminating fact, and it rules out the whole family of length bugs, which is most of the family you would reach for first. If the walk had consumed the wrong number of bytes for a pool entry or a member record, the cursor would have ended up in the wrong place and the assertion would have failed loudly. So the framing is right: every length was read correctly and every record was skipped correctly. What remains is a field whose length is correct but whose interpretation is not. The exception table is the prime candidate in this format for exactly that shape of bug, because its entries are four two-byte fields and a reader that gets the field order or the meaning of the handler index wrong will still consume the right number of bytes and still report the right count. The same shape of defect is possible in a Code attribute if a nested attribute is walked by the wrong rule. The diagnostic that follows directly is to dump the Code attribute's raw bytes and walk them by hand for one method, comparing against javap's disassembly of the same method, which will localise it in a single method rather than a whole file. The general habit is to use the end-of-file assertion as a bisection tool, not just a check: it partitions the space of possible bugs into those that break framing and those that do not, and the second group is much smaller and much more interesting." onclick="checkQuiz('quiz-jvm-header-2', this)">The framing is correct, so the bug is in interpreting a field whose length was read correctly &mdash; most likely the Code attribute's exception table, where four two-byte fields can be read in the wrong order while consuming exactly the right number of bytes. Compare one method's raw bytes against <code>javap -c</code> to localise it</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is ruled out by the premise, which is what makes the premise so informative. The end-of-file assertion passing means the reader consumed exactly the right number of bytes from start to finish, so no length was misjudged, no record was mis-skipped, and no count was misread. A length-accounting bug is precisely the class of defect that makes that assertion fail, because the error accumulates in the cursor position. It is the first hypothesis worth having in most desynchronisation bugs, and here it has been excluded by direct evidence rather than by elimination, which is a much stronger position." onclick="checkQuiz('quiz-jvm-header-2', this)">A pool entry's payload length is being misjudged, so the walk desynchronises and the Code attribute is read from the wrong offset, which the end-of-file assertion should also have caught</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: an assertion that passes is evidence, not just absence of evidence. "The walk ended in the right place" narrows the search space more than any amount of staring at the values, because it eliminates every bug whose mechanism is moving the cursor.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The fixed, self-delimiting layout is the same idea as <a href="/courses/pe/lessons/pe-section-table">a PE section table</a> reached from the opposite direction, and the comparison is worth making carefully because the two formats have made opposite bets on the same problem. A PE file has a header, then a table of section headers, each carrying a name, a virtual size and a raw-data pointer. <strong>Nothing after the table is at a fixed offset</strong>, and a loader that wants the import directory must find it in the table first. The class file has no table and no directory; everything is where counting says it is. PE buys flexibility at the cost of two passes; the class file buys one pass at the cost of inflexibility. The second cost is the one that hurts in practice, and it is why a format with a table can grow a new section without a new version while this one cannot.</p>
                <p>The escape hatch is the interesting part, because it is a third option neither of those formats uses. <strong>An attribute is a name plus a length, and a reader that does not recognise the name skips the length.</strong> That is <a href="/courses/coff/lessons/coff-symbol-table">COFF's auxiliary record</a> idea with the variability pushed into a length field, and it is why a class file can carry an attribute the JVM has never heard of. The parallel to <a href="/courses/dwarf/lessons/dwarf-versions">DWARF's versioned tag ranges</a> is exact in the other direction: DWARF reserved whole numeric ranges per version so a new tag could not collide, while the class file uses a name and gets collision-freedom for nothing. <strong>DWARF pays in tag space, the class file pays in a version number, and both avoid the problem of a new record colliding with an old one.</strong></p>
                <p>The renumbering behaviour has no direct counterpart in the other formats here, and that is because of what a constant pool is for. An <a href="/courses/elf/lessons/symbol-table">ELF symbol table</a> is an array too, and adding a symbol renumbers it &mdash; but nothing <em>inside</em> an ELF file refers to a symbol by index, so the renumbering is invisible to the rest of the file. In a class file, essentially every field is a pool index, so renumbering rewrites the whole file. <strong>The class file's pervasive indirection is what buys it the small code size, and it is also what makes the file unstable under recompilation</strong> &mdash; the same decision producing both the compression and the cache-hostility, and neither being separable from the other.</p>
                <p>Next: <a href="/courses/jvm/lessons/jvm-constant-pool">the constant pool</a> &mdash; twenty tags, and the two-slot rule that makes some indices permanently unusable.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-intro">Previous: Why a Class File</a></span>
                <span><a href="/courses/jvm/lessons/jvm-constant-pool">Next: The Constant Pool</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
