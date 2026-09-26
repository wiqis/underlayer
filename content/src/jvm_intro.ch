// JVM Course — Module 1: The Container
// Concept: what a class file is for, and the four independent implementations
// every claim in this course is checked against.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_intro() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Why a Class File — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Why a Class File</h1>
            <div class="lesson-meta">15 min &middot; Module 1: The Container &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A Java compiler does not produce a program. It produces <strong>a file</strong> &mdash; a single, self-contained, fully resolved artifact that a virtual machine can load, check, and refuse. The compiler's entire output is that file, and the format is the contract between the two halves of the toolchain.</p>
                <p>The interesting part is what the contract has to carry. A native object file is full of unresolved names and meaningless until a linker fills them in. A class file has no linker in the usual sense, no symbol table to resolve, and nothing left dangling. Everything the machine needs to know &mdash; every name, every type, every string &mdash; is in the file already, in one table that everything else points into.</p>
                <p>That table is the constant pool, and it is why this format is worth studying carefully rather than skimming. <strong>The class file is a graph of numbers, and almost every number is an index into one array.</strong> Get the array right and the rest of the format is mechanical; get it wrong and nothing else can be trusted, because every field downstream is a pointer into it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The smallest useful class file, produced by this course's own sample, is 409 bytes and contains twenty-eight constant pool entries for a program that prints one word. Here is the whole shape, in the order the bytes appear:</p>
                <div class="formula">
class file:
    magic                  4 bytes
    minor_version          2 bytes
    major_version          2 bytes
    constant_pool_count    2 bytes
    constant_pool          the pool, and most of the file
    access_flags           2 bytes
    this_class             2 bytes
    super_class            2 bytes
    interfaces_count       2 bytes, then that many 2-byte indices
    fields_count           2 bytes, then that many field records
    methods_count          2 bytes, then that many method records
    attributes_count       2 bytes, then that many attribute records
</div>
                <p>Three things about that layout are worth noticing before any of the details.</p>
                <p><strong>It is not extensible.</strong> There is no section table, no id byte, no length-delimited list of blocks. Every field is at a fixed position given the ones before it, and a reader walks the structure top to bottom knowing what comes next at every step. Compare <a href="/courses/elf/lessons/section-header-table">ELF's section header table</a>, where anything can be anywhere, or <a href="/courses/wasm/lessons/wasm-sections">WebAssembly's numbered sections</a>, where a new id buys a new block. The class file has no mechanism for that, and that is a deliberate trade: <strong>nothing can be added without changing the specification, and in exchange a reader needs no lookup table to find anything.</strong></p>
                <p><strong>It is not the order you wrote.</strong> The pool comes before the class's own name, which comes before its methods, which come before the code inside them. Source order is nowhere in the file. A reader that expects things in the order a programmer thinks about them will be wrong immediately.</p>
                <p><strong>Almost everything is an index.</strong> <code>this_class</code> is a number. A method's name is a number. Its descriptor is a number. Its attributes are a list of numbers that head length-delimited blocks. The class file's central design decision is that <em>naming is indirection</em>, and the constant pool is the table of names.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>What a class file looks like when you ask a real compiler to make one. The source is four lines:</p>
                <div class="hex-dump">
<pre>public class Hello
    public static void main(String[] args)
        System.out.println("hello")
</pre>
                </div>
                <p>And here is what the first sixteen bytes of the result are, annotated completely:</p>
                <div class="hex-dump">
                    <pre>0000: ca fe ba be  00 00 00 46  00 61 0a 00 02 00 03
      |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  +-- 0x0002: cp count
      |  |  |  |  |  |  |  |  |  |  |  |  |  |  +----- 0x000a: the first
      |  |  |  |  |  |  |  |  |  |  |  |  |  |        pool ENTRY, at 0x0a
      |  |  |  |  |  |  |  |  |  |  |  |  |  +---------- 0x0061: a Utf8 tag
      |  |  |  |  |  |  |  |  |  |  |  |  +------------- and 97 bytes of it
      |  |  |  |  |  |  |  |  |  |  |  +---------------- 0x000a: entry length
      |  |  |  |  |  |  |  |  |  |  +------------------- 0x0000: minor version
      |  |  |  |  |  |  |  |  |  +---------------------- 0x0046: major = 70
      |  |  |  |  |  |  |  |  +------------------------- 0x0000: minor (0)
      |  |  |  |  |  |  |  +---------------------------- 0x0000: version high
      |  |  |  |  |  |  +------------------------------- 0x0000: version low
      |  |  |  |  |  +---------------------------------- 0xbe: magic high
      |  |  |  |  +------------------------------------- 0xba: magic
      |  |  |  +---------------------------------------- 0xfe: magic
      +-------------------------------------------------- 0xca: magic
</pre>
                </div>
                <p>One thing in that annotation is the whole first lesson of this course and it is invisible unless you look for it: <strong>the bytes are in the order <code>ca fe ba be</code>, which reads as the number 0xCAFEBABE read big-endian.</strong> The magic number is famous precisely because it reads the same way in a hex dump as it does in the source that checks it. A little-endian reader &mdash; which is what you would write if you were arriving from ELF, PE or x86, all of which are little-endian &mdash; sees the value <code>0xBEBAFECA</code> and rejects the file.</p>
                <p>So: <strong>the class file format is big-endian throughout</strong>, and the magic is not an exception to that rule. It is the rule, stated first, in four bytes, before anything else has a chance to be ambiguous. This is worth sitting on, because it is a design decision with no technical justification &mdash; the JVM had no reason to prefer either endianness &mdash; and it was made the same way the magic was: to be unmistakable. <strong>Both choices exist to catch a mistake at the earliest possible moment.</strong></p>
                <h3>The version pair is not what it looks like</h3>
                <p>Two two-byte fields, and the naming is a trap. <code>minor_version</code> is 0 and <code>major_version</code> is 70. The instinct is to read that as "version 70.0" and be done. Two corrections:</p>
                <ul>
                    <li><strong>The major number is the Java release, not a format version that increments on its own.</strong> Major 70 is Java 26. Major 52 is Java 8, 61 is Java 17. The number is pinned to the language release, which is why a class file from a newer JDK is rejected outright by an older JVM &mdash; there is no partial compatibility, because the file format itself changed with the language.</li>
                    <li><strong>Minor is not a sub-version. It is a feature flag.</strong> It is 0 for everything except preview features, where it is <code>0xFFFF</code>. That is the whole scheme: a minor of 65535 means "this file uses preview features and needs the same JVM build that compiled it". <strong>A two-byte field that is almost always zero and carries one bit of meaning is a shape worth recognising</strong>, because a reader that treats it as part of a version number will accept a preview class file it cannot run.</li>
                </ul>
                <p>And the compatibility rule is absolute rather than graded. A JVM will load a class file whose major version it knows, and refuse one whose major version it does not, with no attempt to read what it can. Compare that to a native binary, where an unknown <a href="/courses/elf/lessons/elf-identification">ELF <code>EI_OSABI</code> byte</a> or an unfamiliar machine type usually produces a warning and a best effort. <strong>The class file format chose a hard boundary over graceful degradation, and it is a boundary the machine can check in four bytes before reading anything else.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What the four independent implementations are, and what each one is good for. This is not decoration: the whole reason this course can make claims is that it has four readers that cannot all be wrong the same way.</p>
                <div class="formula">
READER 1   class_decode.py   written from the specification, by this course.
                             Prints structure. Deliberately NOT a validator.

READER 2   javap -v          the JDK's own disassembler. 30+ years old,
                             and still the thing every Java developer
                             actually reaches for.

READER 3   java.lang.classfile  the JDK's own STANDARD API for parsing class
                             files, added in Java 22. Reaches the parser
                             through a supported interface rather than
                             through a disassembler, so a bug in one
                             implementation cannot hide in both.

ORACLE     the JVM verifier  not a reader at all: it accepts or refuses.
                             A class that loads has passed a format check
                             and a type check performed by code that
                             shares nothing with the three above.
</div>
                <p><strong>Why three readers and not one.</strong> A decoder written from a specification can be wrong in the ways the specification is ambiguous, and it will be confidently wrong, because it has no way to notice. `javap` can be wrong in the ways a disassembler is wrong &mdash; pretty-printing choices, and it is a <em>disassembler</em>, so it is built to show you code rather than to show you bytes. The standard API is neither: it is the JDK parsing its own format through a contract, which makes it the closest thing to an oracle that still prints structure.</p>
                <p>And the oracle is different in kind. A reader tells you what it thinks the file says. The verifier tells you whether the file is <em>legal</em>, and it is the only one of the four that can be right about a file the others misread. That asymmetry is useful: when the three readers agree and the JVM refuses the file, the readers have all missed something real, and hunting for it is the most instructive thing that can happen in this course.</p>
                <p>What the harness actually compares is written down in its own source, at the bottom of the file, because a verification harness whose limits are undocumented will eventually be trusted past them. It compares structure, framing, pool slots and member names. <strong>It does not compare attribute bodies</strong> &mdash; only attribute <em>names</em> &mdash; and it does not compare the values inside constant pool entries. Both limits are stated there rather than left for a reader to discover by hitting them.</p>
                <p>And the harness was itself tested by injecting faults, which is the part most harnesses skip. Five were tried. Three were caught immediately. One was <strong>not</strong> caught, and the reason was a bug in the harness rather than in the decoder: it computed "which pool indices are unusable" in its own code as well as in the decoder's, exercised only its own copy, and so a fault in the other copy passed cleanly. The fix was to make it one function. That episode is written up in the course's research record in full, because <strong>a check that re-implements the thing it is checking is testing the re-implementation</strong>, and the only way to find that out is to break something and see whether the harness notices.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javac -d out Hello.java
$ javap -v -p out/Hello.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Hello.class
$ java -cp courses/jvm/assets/samples Cf out/Hello.class
$ python3 courses/jvm/assets/samples/crosscheck.py</code></pre>
                <ul>
                    <li><strong>Confirm the endianness claim yourself.</strong> Write six lines that read the first four bytes with a big-endian reader and with a little-endian one, and print both. Then read them as four separate bytes. <strong>Three answers, one of which is a famous number, and the hex dump shows you which is which</strong> &mdash; do this before anything else and the rest of the format is easier to reason about.</li>
                    <li><strong>Find the smallest class file you can compile.</strong> An empty class, then one with a single field, then a single method. Watch the constant pool grow. <strong>The marginal cost of a name is the lesson: every name you write becomes an entry someone has to read.</strong></li>
                    <li><strong>Compile the same source at three release levels and compare the version bytes.</strong> <code>javac --release 8</code>, <code>--release 17</code>, and no flag. The major version changes and nothing else in the header does. <strong>Then try to load the newest with <code>java -cp</code> and read the refusal</strong> &mdash; the error message names the version, which is the format's whole compatibility policy in one sentence.</li>
                    <li><strong>Count the pool entries a real library class uses.</strong> Something from the JDK, or a large class of your own. Compare the pool size to the file size. <strong>On a big class the pool is the overwhelming majority of the file</strong>, and that ratio is the strongest argument for the format's central design decision.</li>
                    <li><strong>Break the magic and see how fast it is caught.</strong> Flip one byte of the magic in a copy. Every one of the four implementations refuses it, and three of them refuse it before reading anything else. <strong>Then corrupt a byte deep in the pool and compare how far each gets</strong> &mdash; the hard boundary is only at the front; past that, a reader has to interpret to find out.</li>
                    <li><strong>Add a field and diff the two dumps.</strong> <code>javap -v</code> before and after, then <code>diff</code>. <strong>Almost everything shifts, because the pool is renumbered</strong> &mdash; and that reordering is the next concept's whole subject.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a class file begins <code>ca fe ba be 00 00 00 46</code>. How many bytes is that, what is the version, how is the magic read, and what happens if a reader on a little-endian machine reads those same four bytes as a 32-bit number?</p>
                <div class="quiz" id="quiz-jvm-intro-1">
                    <button class="quiz-option" data-correct="true" data-explain="Eight bytes: four of magic and two two-byte version fields. The magic is read as a big-endian 32-bit integer, which is why 0xCAFEBABE appears in a hex dump in that byte order and why file(1) can recognise the file from four bytes. The format is big-endian throughout, so a little-endian reader sees 0xBEBAFECA and the version fields come out byte-swapped, giving minor 0 and major 0x4600 = 17920, which is a version no JVM has ever heard of. The interesting part is the consequence rather than the arithmetic: the check is the cheapest possible one and it happens first, so a file that is not a class file is rejected in four bytes, and a file from a newer JDK is rejected in six. That is a hard boundary rather than a best effort, and it is the opposite of what ELF does with an unfamiliar EI_OSABI byte, which usually produces a warning. The general habit is to notice when a format has chosen to fail early and totally rather than late and partially, because that choice tells you what the format is optimising for." onclick="checkQuiz('quiz-jvm-intro-1', this)">Eight bytes. Major version 70, which is Java 26, and minor 0. The magic is a big-endian 32-bit read, which is why it looks the same in the dump; a little-endian reader gets <code>0xBEBAFECA</code> and a nonsense major version of 17920, so the file is rejected in the first four bytes</button>
                    <button class="quiz-option" data-correct="false" data-explain="The bytes are big-endian, so the magic is 0xCAFEBABE and the major version is 70, not byte-swapped. The mistake here is reading the file the way an x86 or an ELF file is read, which is the single most common error for anyone arriving from those formats and the reason the magic is worth annotating byte by byte. A little-endian reader would see 0xBEBAFECA, which is not the magic, and would reject the file before ever reaching the version fields at all &mdash; so the claim about a swapped major version describes what would happen if the reader somehow accepted the magic, which is not what happens." onclick="checkQuiz('quiz-jvm-intro-1', this)">Eight bytes. The magic reads as <code>0xBEBAFECA</code> little-endian, giving major version 0x4600, and a conforming reader detects the mismatch only when it reaches the version fields</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a tool that reads class files. It works on every class your build produces and reports the wrong major version for one artifact from a dependency &mdash; a plausible large number, not zero, and not an obviously byte-swapped one. Your tool reads big-endian. The file is 40&nbsp;KB. The dependency was built by a different organisation's JDK, six months older than yours. What is the most likely cause, what is the one-line check, and what does the fact that your tool is <em>big-endian</em> tell you about the diagnosis?</p>
                <div class="quiz" id="quiz-jvm-intro-2">
                    <button class="quiz-option" data-correct="true" data-explain="The evidence rules out the interesting hypotheses and points at one boring one. Being big-endian means the endianness hypothesis is dead, and you established that yourself, which is the point of stating it. A genuine endianness bug would give a byte-swapped major version &mdash; a multiple of 256, a very distinctive signature &mdash; and you say the number is plausible rather than obviously swapped, which is the observation that actually discriminates. A plausible large major version is exactly what an older JDK produces: the major number is pinned to the Java release, so a dependency built six months earlier on an older release has a lower major version, and if your tool validates against a table of versions it knows rather than a range, it rejects a version that is perfectly legal. The one-line check is to read the same eight bytes with a hex dump and compare the two-byte field at offset 6 against the major version your build produces, which settles it in one look with no code involved. The general habit is that a number being wrong in a way that looks deliberate usually means the tool applied a rule the file did not violate, and that the cheapest next step is always to look at the raw bytes rather than to add logging." onclick="checkQuiz('quiz-jvm-intro-2', this)">The dependency was built by an older JDK, so its major version is lower than yours, and your tool validates against a set of known versions rather than a range. Hex-dump the first eight bytes and compare the major at offset 6 with your own build; being big-endian already rules out the endianness explanation</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is ruled out by the tool's own byte order, which you stated, and it is worth noticing that you ruled it out before considering it. A byte-order bug produces a very specific signature: a major version that is a multiple of 256, because the two bytes of the field have traded places. You said the number is plausible and not obviously byte-swapped, which is the observation that excludes this. There is also a practical problem with the hypothesis: a 40 KB class file from a real dependency is very unlikely to be entirely big-endian data, so a reader that got the byte order wrong on the header would almost certainly also get it wrong on the constant pool and produce nonsense long before reporting a version." onclick="checkQuiz('quiz-jvm-intro-2', this)">Your reader is reading the version fields little-endian somewhere despite the big-endian default, so the major version is byte-swapped and only fails for that file because of some other difference in it</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a field reads as a wrong-but-plausible value, the bug is usually a rule being applied too strictly rather than bytes being read wrongly. Plausibility is the signal &mdash; a byte-order bug produces implausible values, which is exactly why they are easy to spot and yours is not.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The class file's fixed, non-extensible layout is the sharpest contrast in this collection, and the three formats it is worth setting it against are all in courses here. <a href="/courses/elf/lessons/section-header-table">ELF</a> puts a table of section headers at the end, each with a type, an offset and a size, so anything can be anywhere and a reader scans the table first. <a href="/courses/coff/lessons/coff-section-table">COFF</a> does something in between: a fixed header, then a table of section headers that gives names and locations. <a href="/courses/wasm/lessons/wasm-sections">WebAssembly</a> numbers its sections and requires them in ascending order, which is a compromise between the two. <strong>The class file takes none of the flexibility, and what it buys is a reader that never has to build an index before it can read anything.</strong></p>
                <p>That choice has a direct cost that this course will keep running into: <strong>every new feature needs a new specification version.</strong> There is no way to add an attribute kind in the abstract &mdash; attributes are already length-delimited blocks, so a new one is easy &mdash; but there is no way to add a new <em>top-level</em> block, and a new class file version is how Java shipped a sealed-classes attribute, records, and every other structural change since 1995. Compare <a href="/courses/pe/lessons/pe-data-directories">the PE data directories</a>, where a producer needing a new table adds a directory entry and bumps a count; or an <a href="/courses/elf/lessons/elf-identification">ELF <code>EI_OSABI</code></a> byte, which exists precisely so a format can grow a variant without a new magic number. <strong>The class file's rigidity is why its major version is the Java release number and not a format counter.</strong></p>
                <p>The endianness point is not isolated either, and it is worth noticing how rare a big-endian executable format is. Every native format in this collection &mdash; ELF, PE, COFF, Mach-O, x86 &mdash; is little-endian on the architectures that actually run, because the hardware is. A network format is big-endian for historical reasons going back to the original IP header. <strong>The class file is a file format with no network role and no hardware constraint, and it chose big-endian anyway</strong>, which means the choice was made for the same reason the magic was: to be visibly, unmistakably not anything else. Both are four bytes of deliberate conspicuousness, and both are stated before there is anything to be ambiguous about.</p>
                <p>Next: <a href="/courses/jvm/lessons/jvm-header">the header and the fixed order</a> &mdash; the eight bytes just decoded, followed by the pool and everything that points into it.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/wasm">Previous course: WebAssembly</a></span>
                <span><a href="/courses/jvm/lessons/jvm-header">Next: The Header and the Fixed Order</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
