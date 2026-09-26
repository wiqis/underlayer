// JVM Course — Module 1: The Container
// Concept: the constant pool — twenty tags, one-based indexing, and the
// two-slot rule that makes some indices permanently unusable.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_constant_pool() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Constant Pool — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>The Constant Pool</h1>
            <div class="lesson-meta">24 min &middot; Module 1: The Container &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every other field in a class file is a number that means &ldquo;look at this row of the constant pool.&rdquo; The class's own name is a pool index. A method's name is a pool index. Its descriptor is a pool index. A <code>Code</code> attribute's name is a pool index. There is no field anywhere in the format that holds a name directly.</p>
                <p>So the constant pool is not one section among several. <strong>It is the table the whole file is made of</strong>, and a reader that gets it wrong cannot recover: every subsequent interpretation is a lookup into a structure it has already misread. This is the opposite of, say, <a href="/courses/elf/lessons/section-header-table">an ELF section header table</a>, which indexes <em>sections</em> and whose entries are mostly self-describing. Here the entries are mostly <em>references to each other</em>, so the pool has to be walked before any of it can be read.</p>
                <p>And it has one rule that catches everybody exactly once: <strong><code>CONSTANT_Long</code> and <code>CONSTANT_Double</code> occupy two indices, and the second one is permanently unusable.</strong> The reason is a good one &mdash; it lets a 64-bit constant be loaded with one uniformly-sized index fetch &mdash; and the consequence is that the pool's indices are not contiguous, which every assumption about &ldquo;the next entry&rdquo; breaks on.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Each entry is a one-byte tag followed by a payload whose size the tag determines. Nothing is length-prefixed &mdash; <strong>the tag <em>is</em> the length</strong>, which is why the pool must be walked entry by entry rather than skipped in one go.</p>
                <div class="formula">
tag  name                   payload                    indices
 1   Utf8                   u2 length + that many bytes    1
 3   Integer                u4, big-endian                1
 4   Float                  u4 (IEEE 754 bits)            1
 5   Long                   u8, big-endian                2   &lt;-- takes two
 6   Double                 u8 (IEEE 754 bits)            2   &lt;-- takes two
 7   Class                  u2 -> a Utf8 index            1
 8   String                 u2 -> a Utf8 index            1
 9   Fieldref               u2 class, u2 NameAndType      1
10   Methodref              u2 class, u2 NameAndType      1
11   InterfaceMethodref     u2 class, u2 NameAndType      1
12   NameAndType            u2 name, u2 descriptor        1
15   MethodHandle           u1 kind, u2 index             1
16   MethodType             u2 -> a Utf8 index            1
17   Dynamic                u2 bsm, u2 NameAndType        1
18   InvokeDynamic          u2 bsm, u2 NameAndType        1
19   Module                 u2 -> a Utf8 index            1
20   Package                u2 -> a Utf8 index            1
</div>
                <p>Twenty tags, and the shape of the table is not uniform in an important way. <strong>Eleven of the twenty are pure indirections</strong> &mdash; a <code>Class</code>, a <code>String</code>, a <code>MethodType</code>, a <code>Module</code>, a <code>Package</code>, and the three <code>*ref</code> tags plus <code>NameAndType</code> &mdash; and they carry nothing but one or two indices. The other nine carry data: five are the constant types, one is the string encoding, and three are the <code>MethodHandle</code> / <code>Dynamic</code> / <code>InvokeDynamic</code> family that Java 7 and 8 added for lambdas.</p>
                <p>So a pool is mostly a graph. <code>this_class</code> points at a <code>Class</code>, which points at a <code>Utf8</code>. A <code>Methodref</code> points at a <code>Class</code> and a <code>NameAndType</code>, and the <code>NameAndType</code> points at two more <code>Utf8</code> entries. <strong>Reading a name means following a chain two or three links long</strong>, and a reader that tries to print names while walking the pool &mdash; before the later entries have been read &mdash; will follow a pointer into a table slot it has not filled in yet.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The two-slot rule, on a real file. <code>Consts.class</code> declares four 64-bit constants, and here is what that does to the pool's numbering. The class is 661 bytes and the pool has a stored count of <strong>52</strong>:</p>
                <div class="hex-dump">
                    <pre>  #20 = Integer            2135567385
  #21 = Utf8               I64
  #22 = Utf8               J
  #23 = Long               81985529216486895l
  #25 = Utf8               F32                 &lt;-- #24 does not exist
  #26 = Utf8               F
  #27 = Float              3.5f
  #28 = Utf8               F64
  #29 = Utf8               D
  #30 = Double             -2.718281828459045d
  #32 = Utf8               S                    &lt;-- #31 does not exist
  #33 = Utf8               Ljava/lang/String;
  #34 = String             #35
  #35 = Utf8               hello
  ...
  #39 = Long               -9223372036854775808l
  #41 = Utf8               NAN2                 &lt;-- #40 does not exist
  #42 = Double             NaNd
  #44 = Utf8               self                &lt;-- #43 does not exist
</pre>
                </div>
                <p>That output is <code>javap</code>'s, and look closely at what it does: <strong>it simply skips the missing indices.</strong> There is no line for <code>#24</code>, no comment, nothing. A reader scanning that listing and assuming consecutive numbering will be wrong by one from <code>#23</code> onward, and by four by the end. The gaps are visible only as an absence, which is the hardest kind of thing to notice.</p>
                <p>So the arithmetic, stated plainly. Four 64-bit constants, four extra indices consumed, and:</p>
                <div class="hex-dump">
                    <pre>  stored constant_pool_count   52
  index 0                       reserved, never valid
  usable entries                47      (52 - 1 for the reserved zero,
                                        - 4 for the second halves)
  highest index actually used    51
  permanently unusable indices    24, 31, 40, 43
</pre>
                </div>
                <p><strong>All of that was confirmed by three independent implementations</strong>, and the third is the interesting one. This course's decoder reports the count, the usable total and the hole list. <code>javap</code> shows the same gaps in its numbering. And the JDK's own standard parsing API &mdash; <code>java.lang.classfile</code>, the supported interface the JVM's own parser is reached through &mdash; reports <code>cpSize 52</code>, <code>cpUsable 47</code>, <code>cpHoles 4</code>, <code>cpHoleIdx 24 31 40 43</code>.</p>
                <div class="callout callout-warn">
                    <strong>And when you ask the JDK for a hole, it throws.</strong> <code>entryByIndex(24)</code> does not return null, does not return the neighbouring entry, and does not return a plausible wrong answer. It raises <code>ConstantPoolException</code>. That is a stronger position than &ldquo;there is a gap you had better notice&rdquo; &mdash; the JDK treats an unusable index as a hard error rather than a silent one. Two more details from the same API, both worth having: its <code>ConstantPool.size()</code> is the <strong>raw stored count of 52</strong>, while <em>iterating</em> it yields only the 47 usable entries, so <strong>the iteration length and <code>size()</code> disagree and that disagreement is the two-slot rule seen from outside the format.</strong> And a reader is expected to use the raw index space, because that is the index space the file's own fields refer to. The API is not being tidy; it is preserving the file's numbering so that a field read from the file can be used to look up a pool entry unchanged.
                </div>
                <h3>Why the rule exists at all</h3>
                <p>Worth understanding, because the design looks like a wart and is actually a trade. The alternative would be to give <code>CONSTANT_Long</code> a two-byte tag, or a tag plus an explicit length, and keep one index per entry. The rule instead works like this: <strong>a pool entry is fetched with a single index operation of a size the runtime can pick from the tag alone</strong>, and a 64-bit value is fetched as one 8-byte unit rather than as two 4-byte halves the runtime has to reassemble. Constant pool entries are the hottest data in the whole format &mdash; every field access, every method call, every type check goes through them &mdash; so the format spends indices to make the fetch trivial.</p>
                <p>The cost is paid by readers, once, in one place: <strong>you cannot iterate the pool by incrementing an index</strong>. Every loop has to ask how many indices the current entry consumed. Get that wrong and you are off by one from the first <code>Long</code> onward, reading a Utf8's length byte as a tag, and from there producing plausible nonsense &mdash; because a Utf8 tag is <code>0x01</code> and a length byte is very often a small number, so the desync does not announce itself. It surfaces as a pool entry with a nonsensical tag, at which point a careful reader stops; an unlucky one keeps going.</p>
                <p>And there is a second, quieter cost. <strong>The pool's size is not derivable from its content</strong>, so nothing can be built by streaming: the walk must know, at every entry, whether the next index exists. A reader that wants random access &mdash; which is what an index-based design invites &mdash; has to carry a bitmap of holes or check a flag on every lookup. <strong>For a design whose whole premise is that the pool is a random-access table, that is an awkward cost to pay in the table's primary use case.</strong></p>
                <h3>The reserved zero, and why one-based</h3>
                <p>Index 0 is never a valid entry, which is what makes the stored count one more than the number of entries. The reason is not arbitrary: <strong>zero is what an uninitialised field reads as</strong>, and every index in the file is a 16-bit unsigned number where <code>0x0000</code> is a perfectly ordinary-looking value. Reserving it means a field that was never set, or was set by a buggy producer, is a detectable error rather than a silent reference to whatever happens to be at the front of the table. The same argument applies to <code>super_class</code>, where 0 is legal and means <code>java.lang.Object</code> for the one class that has no superclass &mdash; <code>java.lang.Object</code> itself.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Walking the pool correctly, which is the whole skill, and the one place the two-slot rule has to be honoured:</p>
                <div class="formula">
walk_pool(data, start, cp_count):

    p = start
    i = 1                       # one-based, and 0 is reserved

    while i &lt; cp_count:         # NOT &lt;= : the count is one past the last
        tag = data[p];  p += 1

        if   tag == Utf8:    n = u2(p);            p += 2 + n
        elif tag == Integer: p += 4
        elif tag == Float:   p += 4
        elif tag == Long:    p += 8
        elif tag == Double:  p += 8
        elif tag in (Class, String, MethodType, Module, Package):
                             p += 2
        elif tag in (Fieldref, Methodref, InterfaceMethodref, NameAndType,
                     Dynamic, InvokeDynamic):
                             p += 4
        elif tag == MethodHandle: p += 3
        else: raise Bad("unknown tag %d at index %d" % (tag, i))

        # THE RULE. Long and Double consume the index after this one as well,
        # and that index is not an entry -- so `i` skips it, and no valid
        # reference can ever name it.
        i += 2 if tag in (Long, Double) else 1

    return p                   # must equal start_of_this_class
</div>
                <p>Two details in that are where implementations actually go wrong, and both are consequences of the same design.</p>
                <p><strong>The loop condition is <code>i &lt; cp_count</code>, not <code>&lt;=</code>.</strong> The stored count is one past the highest usable index, which is the direct consequence of one-based indexing with a reserved zero. A reader that loops inclusively reads one entry past the end of the pool. Because the pool is immediately followed by <code>access_flags</code>, that "extra entry" is read out of the class header, and since <code>access_flags</code> for a public class is <code>0x0021</code>, its low byte <code>0x21</code> = 33 is not a valid tag &mdash; so a strict reader stops, and a lenient one tries to parse 33 as a tag and fails more confusingly further on.</p>
                <p><strong>The index advance and the byte advance are different numbers</strong>, and keeping them in step is the entire skill. <code>CONSTANT_Utf8</code> advances the byte cursor by a <em>variable</em> amount and the index by exactly one. <code>Long</code> advances eight bytes and the index by two. There is no single "entry size" to compute, which is why the format makes the tag do the work and why a decoder that assumes fixed-size entries cannot work at all.</p>
                <p>Now the failure that this course verified, because it is the most instructive thing in the concept. A reader that advances the index by one always, ignoring the two-slot rule, gets a plausible-looking answer for a while and then stops:</p>
                <div class="hex-dump">
                    <pre>  correct:   #23 Long, then #25 Utf8     (24 is a hole)

  ignoring the rule:  #23 Long, then #24
                      but #24 is the SECOND HALF of the Long's 8-byte
                      payload -- its high 4 bytes, which for the value
                      0x0123456789ABCDEF are 01 23 45 67

  so the "tag" at #24 is 0x01, which is Utf8
      -> the reader believes it has found a Utf8
      -> it reads the next two bytes as a length: 23 45 = 0x2345 = 9029
      -> it skips 9029 bytes and is now 9000 bytes past the end of a
         661-byte file

  and the error message, when it finally surfaces, names a tag and an
  offset rather than the two-slot rule that actually caused it.
</pre>
                </div>
                <p><strong>The high half of a Long is usually a small, plausible byte, and small bytes are valid-looking tags.</strong> That is why this bug is so much harder to catch than an off-by-one in a fixed-size table: the first symptom is nine kilobytes downstream, at an offset that has nothing to do with the mistake. The general habit is the one this course has now established twice, in two unrelated formats: <strong>when a decoder reports a wild offset, the bug is usually a few records earlier, and the arithmetic that produced the wild number is the place to look rather than the position it was found at.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Consts.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Consts.class
$ python3 courses/jvm/assets/samples/crosscheck.py classes/Consts.class</code></pre>
                <ul>
                    <li><strong>Count the holes yourself before reading the explanation.</strong> Take <code>Consts.class</code>, list every <code>Long</code> and <code>Double</code> index, and write down what you think the next index is after each. Then check against the real listing. <strong>Four constants, four holes, and the arithmetic is one subtraction</strong> &mdash; do the arithmetic before being told it, and the rule sticks permanently.</li>
                    <li><strong>Make a pool with exactly one long and confirm the hole.</strong> A class with a single <code>static final long</code> and nothing else numeric. The pool should have one unusable index. <strong>Minimal cases are where a rule is easiest to see and easiest to get wrong</strong>, because there is nothing to hide behind.</li>
                    <li><strong>Write the hole-finding code, then break it on purpose.</strong> Compute the unusable indices two ways &mdash; by scanning for missing indices, and by accumulating a step per tag &mdash; and confirm they agree. Then hard-code the step to 1 and watch the walk run off the end of the file. <strong>The crash is at the wrong place, which is the lesson.</strong></li>
                    <li><strong>Compare the three readers on the same file and find the disagreement.</strong> Run all three on <code>Consts.class</code>. Two of them report the holes; <code>javap</code> only implies them by skipping. <strong>Then write the three-line program that asks the JDK API for index 24 and catches the exception</strong> &mdash; that is the strongest evidence in the course, and it is four lines long.</li>
                    <li><strong>See what the rule costs a real tool.</strong> Try to write a pool iterator that does not know the tags, and confirm you cannot. Then write one that does, and count how many tags you had to handle. <strong>There is no generic "skip one entry" for this format</strong>, and that is worth feeling directly rather than reading.</li>
                    <li><strong>Trace a name all the way down.</strong> Pick a <code>Methodref</code> in <code>Hello.class</code> and follow it: <code>Methodref</code> to a <code>Class</code> to a <code>Utf8</code>, and a <code>NameAndType</code> to two more <code>Utf8</code> entries. Count the hops. <strong>That chain is why a naive disassembler cannot print a method name until the entire pool has been read</strong> &mdash; and the reason a pool walker that prints as it goes produces nonsense.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a class file's <code>constant_pool_count</code> is 52, and the pool contains four <code>CONSTANT_Long</code> or <code>CONSTANT_Double</code> entries. How many usable entries are there, which indices are unusable, and what happens to a reader that starts its loop at index 0?</p>
                <div class="quiz" id="quiz-jvm-constant-pool-1">
                    <button class="quiz-option" data-correct="true" data-explain="Three separate facts combine here, and each is easy to get wrong in isolation. The count of 52 covers index 0, which is reserved and never valid, so subtracting it gives the indices 1 to 51. Four 64-bit constants each consume a second index that no entry occupies, so four of those 51 are holes and 47 entries are real. Which four depends on where the Longs and Doubles sit in the compilation order, and for this file they are 24, 31, 40 and 43. A reader starting at index 0 does two separate wrong things. It resolves the reserved slot, which is never a valid entry, and because most pool entries are Utf8 the result is likely to be a plausible string rather than an obvious error. And it then runs one iteration past the real end of the table, reading whatever follows the pool, which is access_flags -- and since a public class has 0x0021 there, the low byte 0x21 = 33 is read as a tag, which is not a valid one. So the symptom is either a meaningless name or an invalid tag, and neither points at the cause. The general habit is that one-based tables with a reserved zero need the zero checked explicitly rather than merely stepped over, because the format uses zero as the natural value of an unset field." onclick="checkQuiz('quiz-jvm-constant-pool-1', this)">Forty-seven usable entries. The unusable indices are 24, 31, 40 and 43 &mdash; the second half of each 64-bit constant. A reader starting at index 0 resolves the reserved slot, which holds no valid entry, and then runs one iteration past the end of the pool into the class header, where it will read a byte as an invalid tag</button>
                    <button class="quiz-option" data-correct="false" data-explain="The count is the easy part and the reasoning after it is where this goes wrong. Fifty-two minus the reserved zero is 51 indices in use, and four of those are the unusable second halves of the 64-bit constants, leaving 47 real entries -- the four do not simply vanish from the index space, they remain as gaps a reader must know to skip. And the consequence of starting at zero is not that the reader ends up at the wrong place; it is two distinct things at once, one at each end of the loop. Starting at zero resolves an index the format guarantees is meaningless, which yields a plausible-looking wrong name, and the inclusive-versus-exclusive confusion is a different mistake with a different symptom." onclick="checkQuiz('quiz-jvm-constant-pool-1', this)">Forty-eight usable entries, and a reader starting at index 0 simply reads the reserved slot as if it were a real entry, producing one wrong name but otherwise a correct walk</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your class file reader handles nine of your project's hundred classes. The other ninety-one produce an error like <code>unknown constant pool tag 1 at index 0x1D4</code>, and the offset is far past the end of the file. The nine that work have no 64-bit constants anywhere in their constant pools. The ninety-one that fail each have at least one <code>static final long</code>. What is the defect, why does the error message point at the wrong thing, and what is the general habit that would have found it before ninety-one classes failed?</p>
                <div class="quiz" id="quiz-jvm-constant-pool-2">
                    <button class="quiz-option" data-correct="true" data-explain="The evidence is unusually clean and it points at exactly one thing. Nine working classes have no 64-bit constants; ninety-one failing classes each have at least one. That is a perfect correlation with a single format rule, and the only rule about the constant pool that depends on which tags appear is the two-slot rule. The defect is advancing the index by one for every entry, so the index after a Long or a Double lands on the second half of its eight-byte payload. The error message points at the wrong thing because that second half is not a separate record at all -- it is the high four bytes of a value, and for a long like 0x0123456789ABCDEF those bytes are 01 23 45 67, so the reader reads 0x01 as a tag, believes it has found a Utf8, reads the next two bytes as a length, gets 0x2345 = 9029, and skips 9029 bytes. The failure therefore surfaces thousands of bytes past the mistake, at an offset that looks like it could not possibly be related to a two-byte error. The habit that finds it is to make the smallest sample that contains one instance of the construct under suspicion -- one class, one long, nothing else -- and confirm the decoder handles it before running a corpus. A hundred-class corpus with a rule that fires on 91 of them is a very expensive way to learn a rule you could have learned on a five-line file, and the general principle is that a decoder's first test should be the case most likely to break it, not the case most likely to pass." onclick="checkQuiz('quiz-jvm-constant-pool-2', this)">The reader advances the index by one for every entry, so after a <code>Long</code> it lands on the second half of the 8-byte payload and reads one of those bytes as a tag. The message is misleading because those bytes are ordinary-looking, so the walk continues and fails thousands of bytes later. Test on a minimal class containing one <code>static final long</code> before running any corpus</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is ruled out by the correlation in the evidence, which is the strongest thing in the report. If the loop bound were off by one, the read past the end would happen in every file, including the nine that work, because every pool ends and the class header always follows. The failures track the presence of 64-bit constants exactly, and the loop bound has nothing to do with which tags a file contains. There is also a practical objection: the reported offset is thousands of bytes past the end, and a one-iteration overrun would produce a small, local, easily diagnosed error rather than a wild one." onclick="checkQuiz('quiz-jvm-constant-pool-2', this)">The loop bound is off by one, so every class reads one entry past the end of the pool, and the 64-bit constants only make it worse by shifting where the error lands</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a bug correlates perfectly with one syntactic feature of the input, that feature is the cause until proven otherwise &mdash; and the smallest sample containing one instance of it is the fastest test available, by a wide margin.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The two-slot rule is a run-length encoding in a place where nothing is repeated, and that is worth seeing as a category rather than a curiosity. <a href="/courses/coff/lessons/coff-symbol-table">A COFF auxiliary record</a> lets one 18-byte symbol stand for several by carrying a count; <a href="/courses/wasm/lessons/wasm-code">a WebAssembly local declaration group</a> does the same for a run of same-typed locals. Both save space by <strong>declaring a multiplicity</strong>. This rule saves no space at all &mdash; a <code>Long</code> occupies eight bytes either way &mdash; and spends a pool index to buy a cheaper fetch. <strong>Same shape, opposite purpose</strong>, and the difference is instructive: the multiplicity there compresses data, while here it aligns an access pattern. A format is full of encodings that exist for a machine rather than for a file size, and this is the cleanest example in the collection.</p>
                <p>The index-as-everything design is the class file's answer to a question <a href="/courses/pe/lessons/pe-imports">a PE file</a> answers differently. In a PE, a call target is a <em>relative displacement</em> patched into the instruction, and the symbol it referred to lived in a separate directory. In a class file there is no patching at all: an <code>invokevirtual</code> carries a pool index and the name is simply looked up. <strong>Nothing is relative, nothing is patched, and there is no linker</strong> &mdash; which is why a class file is self-contained and why the only renumbering that happens is at compile time, as the previous concept showed.</p>
                <p>The one-based indexing with a reserved zero has a close cousin in <a href="/courses/dwarf/lessons/dwarf-dies">DWARF</a>, where index 0 in a <code>.debug_str</code> or a section table is conventionally a sentinel meaning "absent" rather than "the first thing". Both formats use a zero that means <em>nothing</em> in a space where zero would otherwise be a perfectly good value, and both do it so that an unset field is detectable. The <a href="/courses/wasm/lessons/wasm-globals">WebAssembly mutability byte</a> makes the same move more explicitly &mdash; <code>0x00</code> and <code>0x01</code> for no and yes, with nothing else legal &mdash; and pays for the explicitness with a reader that accepts only two values.</p>
                <p>And the "pool is a random-access table, which is awkward" tension is the same one that <a href="/courses/elf/lessons/section-header-table">an ELF section header table</a> creates and solves differently. ELF's table entries are fixed-size and self-locating, so a reader can jump to any one; the class file's entries are variable-size and mostly references to each other, so a reader must walk the whole thing before it can resolve anything. <strong>ELF optimises for random access and the class file for compactness, and the two-slot rule is a small, concrete instance of the compactness choice costing something at the other end.</strong> Nothing in the format is arbitrary; it is a series of trades, and this one is unusually easy to see.</p>
                <p>Next: <a href="/courses/jvm/lessons/jvm-strings">modified UTF-8</a> &mdash; the encoding the <code>Utf8</code> entries use, which is not the one it is named after, and which is the only place in the format where a text encoding rather than a number is the thing to get right.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-header">Previous: The Header and the Fixed Order</a></span>
                <span><a href="/courses/jvm/lessons/jvm-strings">Next: Modified UTF-8</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
