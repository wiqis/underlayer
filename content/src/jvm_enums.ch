// JVM Course — Module 4: Object Shapes
// Concept: enums — ACC_ENUM in two flag tables at once, a synthetic field, and
// two methods that look synthetic but are not.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_enums() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Enums — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Enums</h1>
            <div class="lesson-meta">19 min &middot; Module 4: Object Shapes &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Java's <code>enum</code> looks like a language feature with a type system behind it. In the class file it is <strong>a flag bit in two different flag tables and a list of static fields</strong> &mdash; there is no enum structure anywhere in the format, no enum attribute, and nothing that records "these fields are the constants".</p>
                <p>Which makes an enum the format's clearest case of <strong>a type with a compile-time contract expressed through conventions the machine does not enforce.</strong> The JVM knows an object is an enum because its superclass is <code>java.lang.Enum</code>, and <code>java.lang.Enum</code> implements the <code>values()</code> and <code>valueOf()</code> machinery by reflecting over the declared fields. The format stores the fields. The <em>meaning</em> of the fields is entirely in the class hierarchy and in <code>java.lang.Enum</code>'s own code.</p>
                <p>So an enum is the opposite of a <a href="/courses/jvm/lessons/jvm-records">record</a>, and worth reading beside it. A record's declaration is a first-class attribute. An enum's is a flag bit plus a convention. <strong>One shape is machine-readable and enforced; the other is reconstructable at run time by reflection over a superclass in the JDK.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>There is no enum structure to model, which is itself the model. The whole encoding is four facts:</p>
                <div class="formula">
  1. the CLASS has ACC_ENUM  (0x4000) in the class flag table
  2. the CLASS extends java/lang/Enum&lt;E&gt;
  3. each CONSTANT is a static field with ACC_ENUM (0x4000)
     in the FIELD flag table -- the same bit, same value
  4. the constructor is private

  and nothing else. There is no enum attribute, no count of
  constants, and no record saying which fields are the constants.
</div>
                <p>Fact 3 is the one that catches people, and it is the third appearance of the multiple-flag-tables lesson from <a href="/courses/jvm/lessons/jvm-members">Module 2</a>. <strong><code>0x4000</code> is <code>ACC_ENUM</code> in both the class table and the field table</strong>, and it means the same thing in each: "this is an enum" and "this field is an enum constant". The bit is shared because the concept is shared, and that is a genuine convenience &mdash; unlike <a href="/courses/jvm/lessons/jvm-inner-classes"><code>InnerClasses</code>'s <code>0x0008</code></a>, which means different things in different tables. A reader needs the right table for the right field, but for this bit the answer happens to agree.</p>
                <p>And fact 2 is what makes the format's silence workable. <strong><code>java.lang.Enum</code> contains a private static array that every enum subclass shares, keyed by the subclass</strong>, and it is initialised by scanning the subclass's declared fields for <code>ACC_ENUM</code>. That is the whole discovery mechanism: a reflection pass over fields, filtering on the flag bit.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>A two-constant enum nested inside another class, and every member with its flags. This is the complete <code>Inner$E.class</code>:</p>
                <div class="hex-dump">
                    <pre>  flags: (0x4030) ACC_FINAL, ACC_SUPER, ACC_ENUM

  public static final Inner$E A;      flags: 0x4019
                                       PUBLIC | STATIC | FINAL | ENUM
  public static final Inner$E B;      flags: 0x4019
                                       PUBLIC | STATIC | FINAL | ENUM

  private static final Inner$E[] $VALUES;   flags: 0x101a
                                       PRIVATE | STATIC | FINAL | SYNTHETIC

  public static Inner$E[] values();        flags: 0x0009
                                       PUBLIC | STATIC            &lt;- NOT synthetic
  public static Inner$E valueOf(String);  flags: 0x0009
                                       PUBLIC | STATIC            &lt;- NOT synthetic

  private Inner$E();                       flags: 0x0002
                                       PRIVATE

  private static Inner$E[] $values();      flags: 0x100a
                                       PRIVATE | STATIC | SYNTHETIC

  static initialiser                      flags: 0x0008
                                       STATIC
</pre>
                </div>
                <p>Six source words &mdash; <code>enum E</code> declaring constants A and B &mdash; produce eight members, and the flags are more informative than the names.</p>
                <h3>The finding: the public methods are not synthetic</h3>
                <p><code>values()</code> and <code>valueOf(String)</code> are <code>0x0009</code>: <code>ACC_PUBLIC | ACC_STATIC</code> and nothing else. <strong>No <code>ACC_SYNTHETIC</code> bit.</strong> The natural expectation &mdash; that compiler-generated members are marked synthetic, and the <a href="/courses/jvm/lessons/jvm-code"><code>Code</code> concept</a>'s discussion of bridge and synthetic methods &mdash; says otherwise.</p>
                <p>The reason is that they are not generated implementations at all. <strong>They are real, small methods whose bodies call <code>java.lang.Enum</code>'s protected machinery</strong>, and they are part of the enum's public contract: <code>Colour.values()</code> in source compiles to <code>invokestatic values</code>, and the compiler must be able to resolve that name. A method that source code calls by name cannot be synthetic, because synthetic means "not part of the language's surface" and these are about as much surface as a class has.</p>
                <p>Which makes the contrast with the other two entries the point of the concept. <strong><code>$VALUES</code> and <code>$values()</code> are genuinely synthetic</strong> &mdash; the former is the cached array, the latter is a bridge that exists so <code>java.lang.Enum</code>'s own internals can reach it. Neither is callable from source, and both carry <code>0x1000</code>. So the file contains <em>two kinds</em> of compiler-added member and the flag distinguishes them correctly: <strong>the ones the language exposes are unmarked, the ones the implementation needs are marked.</strong> A tool that hides synthetic members will correctly hide the array and show the API.</p>
                <h3>Why the constructor is private, and why the class is final</h3>
                <p><code>ACC_FINAL</code> on the class (<code>0x4030</code> includes <code>0x0010</code>) and <code>ACC_PRIVATE</code> on the constructor are the same constraint stated twice, and they are what stop the two things an enum must not be: <strong>subclassed, and instantiated from outside</strong>.</p>
                <p>The <em>superclass</em> is the other half. <code>Inner$E extends java.lang.Enum&lt;Inner$E&gt;</code> &mdash; <code>java.lang.Enum</code>'s constructor is <code>protected Enum(String name, int ordinal)</code>, and the enum's private constructor calls it with the name and the ordinal. <strong>So the constant's name and position are passed to a superclass that stores them</strong>, and <code>toString()</code> returns the name and <code>ordinal()</code> returns the position, both inherited unchanged. The enum's identity is established once, in the superclass constructor, and the class file only has to supply the two values.</p>
                <p>Which explains the one piece of machinery the format does provide: <strong><code>java.lang.Enum</code>'s <code>$VALUES</code> array, per subclass</strong>, initialised by the static initialiser. The <code>&lt;clinit&gt;</code> shown above is the method that creates each constant in declaration order, assigns <code>$VALUES</code>, and is why an enum cannot be initialised cyclically &mdash; the order is the source order, fixed at compile time.</p>
                <div class="callout callout-warn">
                    <strong>And there is a fourth fact that is not in the file: the constant's type.</strong> <code>A</code> has descriptor <code>LInner$E;</code> &mdash; the enum's own type, not <code>Object</code> and not <code>java.lang.Enum</code>. So each constant is a field whose type is the class that declares it, and the static initialiser constructs an instance of the class being initialised. <strong>A class whose static initialiser constructs instances of itself is legal only because the field is not <code>final</code>-read at verification time in a way that would fail</strong> &mdash; and the verifier accepts it because the constants' <code>ACC_FINAL</code> is satisfied by the initialiser rather than by a compile-time constant, which is a distinction that exists specifically to make this pattern work. The two flags on the constant, <code>ACC_ENUM</code> and <code>ACC_FINAL</code>, therefore mean different things at the bytecode level: one says "this is a constant", the other says "this is a constant <em>of an enum</em>".
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What an enum costs and what it buys, told as the mechanism a tool would have to write. The class file records the fields; <strong>the semantics live in <code>java.lang.Enum</code> and are recovered at run time by a reflective scan</strong>:</p>
                <div class="formula">
  what the FILE says:               what it MEANS:
  ---------------                    ---------------
  4 static fields, ACC_ENUM          4 constants, in declaration order
  extends java/lang/Enum            the type has the enum's methods
  private constructor                cannot be created from outside
  ACC_FINAL on the class             cannot be extended
  (no attribute)                     nothing -- and that is the point


  the discovery algorithm, in java.lang.Enum:

    Class&lt;?> enumType = subclass of java.lang.Enum
    Field[] fields = enumType.getDeclaredFields()
    keep the ones with ACC_ENUM        &lt;- the flag is the selector
    read each field's value            &lt;- forces &lt;clinit&gt;
    store the array in a per-class cache
    valueOf(name) = search that array by name, throw if absent
</div>
                <p><strong>That is why there is no enum attribute.</strong> The constant list is already in the file, in a form reflection can enumerate, tagged with a bit that says which of the fields count. An explicit list of constants would duplicate information the file already carries in a machine-parseable way, and the <a href="/courses/jvm/lessons/jvm-attributes">escape hatch's</a> whole design philosophy says do not add a structure for something already present.</p>
                <p>So the trade is this. <strong>The format stores less and the machine recovers the rest</strong>, which is why an enum is a few hundred bytes of fields and a <code>&lt;clinit&gt;</code> rather than a table of names and ordinals. And the cost is that the guarantee is only as strong as the convention: a class with <code>ACC_ENUM</code> that does not extend <code>java.lang.Enum</code> is not an enum, and a class that does extend it with <code>ACC_ENUM</code> fields is an enum whether or not the source said <code>enum</code>. The flag is a hint to the reflective scan, not a checked declaration &mdash; the opposite of <a href="/courses/jvm/lessons/jvm-sealed">a sealed class's permitted list</a>, which the verifier enforces.</p>
                <p>And the ordinal deserves a note, because it is the thing people get wrong. <strong>The ordinal is the field's <em>declaration index</em> among the <code>ACC_ENUM</code> fields, and it is not stable.</strong> Reordering the constants changes every ordinal after the moved one, and serialising an ordinal and deserialising it against a reordered enum gives a silently wrong constant &mdash; not an error, a wrong answer. That is a real hazard and it is a direct consequence of the encoding: the ordinal is not recorded anywhere in the file, it is <em>derived</em> from field order, and nothing in the class file ties it to a source declaration. <strong>A format that stored the ordinal explicitly could detect the mismatch; one that derives it cannot.</strong></p>
                <p>Compare that to how the same problem is handled elsewhere in this collection. <a href="/courses/coff/lessons/coff-relocations">A COFF relocation's ordinal</a> is a position in a symbol table, so a reordered table invalidates it &mdash; and the tool that reads it knows the ordinal is a position. <a href="/courses/pe/lessons/pe-imports">A PE import ordinal</a> is likewise a position, and the loader resolves it against the import directory. <strong>In both, an ordinal is a resolved position; in Java's enums, the ordinal is a derived one that nothing checks.</strong> That is the same category of hazard as a table index that can go stale, and it is the clearest reason to prefer names when persisting anything derived from a field order.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Inner\$E.class
$ python3 courses/jvm/assets/samples/crosscheck.py classes/Inner\$E.class</code></pre>
                <ul>
                    <li><strong>Read all eight flags.</strong> Class, two constants, <code>$VALUES</code>, <code>values</code>, <code>valueOf</code>, the constructor, and <code>$values</code>. <strong>Then sort them into the ones the source implied and the ones it did not</strong> &mdash; four of the eight exist in no source file.</li>
                    <li><strong>Confirm the synthetic finding.</strong> <code>values()</code> and <code>valueOf(String)</code> are <code>0x0009</code> with no synthetic bit, while <code>$VALUES</code> and <code>$values()</code> are <code>0x101a</code> and <code>0x100a</code>. <strong>Explain why the two public methods are not synthetic</strong>, and the answer &mdash; source code calls them by name &mdash; is the whole reason.</li>
                    <li><strong>Find the discovery mechanism at run time.</strong> A three-line program that reflects on an enum's declared fields and filters on <code>ACC_ENUM</code>, printing what <code>java.lang.Enum</code> does. <strong>That is the format's entire enum semantics, executed in front of you</strong> &mdash; and it explains why there is no enum attribute.</li>
                    <li><strong>Reorder the constants and watch the ordinals change.</strong> Swap two enum constants, recompile, print <code>ordinal()</code>. <strong>Every constant after the swap has a different ordinal</strong> &mdash; and nothing in either class file records the old one, because the ordinal was never stored.</li>
                    <li><strong>Set <code>ACC_ENUM</code> on a non-enum static field.</strong> A class extending <code>java.lang.Enum</code> with an extra static final field carrying the bit. <strong>It shows up in <code>values()</code></strong> &mdash; the flag is a selector for a reflective scan, not a checked declaration, and that asymmetry with sealing is the concept's real lesson.</li>
                    <li><strong>Add an enum constant and count the bytes.</strong> <strong>Two fields, one <code>name</code> and one <code>descriptor</code> Utf8, two <code>CONSTANT_String</code>s, plus the <code>&lt;clinit&gt;</code> body</strong> &mdash; and the <code>Enum.name</code>/<code>ordinal</code> strings are shared across every enum in the file. A little arithmetic on where the size goes, and it is not where a reader expects.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an enum's two constants are <code>public static final</code> fields with flags <code>0x4019</code>, the class has flags <code>0x4030</code>, and <code>values()</code> has flags <code>0x0009</code>. Which of those three flag values tells the machine something it could not work out otherwise, and what specifically happens if <code>values()</code> carried <code>ACC_SYNTHETIC</code>? Would the class still load?</p>
                <div class="quiz" id="quiz-jvm-enums-1">
                    <button class="quiz-option" data-correct="true" data-explain="The ACC_ENUM bits are the ones that carry information, and they work by being a selector rather than a declaration. ACC_ENUM on a field is what java.lang.Enum's reflective scan filters on, so without it the field is not a constant and simply does not appear in values(). ACC_ENUM on the class is what tells a tool this is an enum at all, since the file has no enum attribute -- though the superclass is the stronger signal, since the real mechanism is the reflective scan in the JDK. The synthetic question has a clean answer: the class would still load, because ACC_SYNTHETIC is a marker for reflection-based tools, and the JVM's verifier does not consult it. But source compiled against it would break, and that is the interesting part. Source code calling Colour.values() compiles to a plain invokestatic against a method name, and the compiler resolves that name against the class's real members. A synthetic member is one the language does not expose, so javac would reject the call even though the method exists and works if invoked reflectively. Synthetic means invisible to the language, not forbidden to the machine, and those are different things -- which is exactly why a real method that the language calls by name must not carry the bit." onclick="checkQuiz('quiz-jvm-enums-1', this)">The <code>ACC_ENUM</code> bits &mdash; on a field they are the selector <code>java.lang.Enum</code>'s reflective scan filters by, on the class they mark it as an enum at all. The class would still load, because <code>ACC_SYNTHETIC</code> is a reflection marker the verifier ignores &mdash; but <code>values()</code> would become invisible to <code>javac</code>, so source calling it would stop compiling</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion about ACC_ENUM is right and the synthetic consequence is wrong, and the direction of the error is the useful part. ACC_SYNTHETIC is a marker consumed by reflection-based tooling, not a flag the verifier or the class loader acts on -- marking a method synthetic does not make the class unverifiable or unloadable, and every synthetic method in every class file in the JDK would contradict that. So the class loads. But the consequence is not that the class is broken at load, it is that the language loses access to it: a synthetic member is by definition not part of the class's surface, so a compiler resolving a call to values() against the declared members would not find it and would report an error, even though the method is present and callable. That is the distinction worth holding: synthetic is about visibility to the language, not about validity to the machine, and the two are independent." onclick="checkQuiz('quiz-jvm-enums-1', this)">The <code>ACC_ENUM</code> bits. The class would be rejected at load if <code>values()</code> were synthetic, because <code>ACC_SYNTHETIC</code> on a method the class's own initialiser or superclass contract depends on is an inconsistency the verifier checks</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a decompiler. It reads the class flag table, finds <code>ACC_ENUM</code>, and reports the class as an enum with the constants listed from the fields carrying the bit. On one class it reports four constants when the source declared two. The class extends <code>java.lang.Enum</code> correctly and the file is otherwise valid. What has happened, and what is the general principle about which kinds of format fact can be trusted without a check?</p>
                <div class="quiz" id="quiz-jvm-enums-2">
                    <button class="quiz-option" data-correct="true" data-explain="The decompiler has done exactly what java.lang.Enum does, which is the real answer and the reason the output is not a bug in the decompiler. ACC_ENUM is a selector for a reflective scan, not a checked declaration: the format states no rule that an enum's constants are the ACC_ENUM fields, and the convention that ties them together lives in the JDK. A field carrying the bit on an enum class is therefore a constant as far as the runtime is concerned, whatever the source said, and reporting four is reporting the file faithfully. The general principle follows directly and is the one worth taking away: a fact the format checks is trustworthy on its own, and a fact the format merely stores is trustworthy only under a convention that some other component owns. PermittedSubclasses is checked by the verifier, so a list that is present is a list that holds. ACC_ENUM is read by a reflective scan in java.lang.Enum, so a bit that is present is a bit the scan will act on, and the source's intent is not part of the picture. A tool reading either one has to know which kind it is reading, and the tell is whether the format has a rule it can violate -- if a file can be malformed here, the machine checks it, and if it cannot, the convention is doing the work." onclick="checkQuiz('quiz-jvm-enums-2', this)">Nothing went wrong: the decompiler did what <code>java.lang.Enum</code> does. <code>ACC_ENUM</code> is a selector for a reflective scan, not a checked declaration, so an extra field carrying the bit genuinely is a constant to the runtime. The principle is that a fact the format <em>checks</em> is trustworthy on its own, while a fact it merely <em>stores</em> is trustworthy only under a convention another component owns</button>
                    <button class="quiz-option" data-correct="false" data-explain="The decompiler's behaviour is required, not a defect. The format has no rule that an enum's constants are exactly the ACC_ENUM fields, so a file that carries the bit on an extra field is a well-formed file, and the JVM's own discovery path treats it as a constant. A decompiler that ignored the extra fields would be the wrong one, because it would be reporting what the source probably said rather than what the file says, and the whole discipline of reading a binary is reporting the file. The trust question is real and it is the right question, but the answer distinguishes checked facts from stored ones rather than assuming a class-file fact is unchecked because a field exists for it. Nothing in the format or the verifier inspects the relationship between an enum's fields and its source, so the decompiler has no basis for calling four wrong, and the fact that it disagrees with the source is information about the source or the compiler, not about the file." onclick="checkQuiz('quiz-jvm-enums-2', this)">The decompiler is wrong to trust a flag bit. <code>ACC_ENUM</code> marks a field's type but the format's only record of which fields are constants is the compiler's convention, so a tool must cross-check the <code>&lt;clinit&gt;</code> and treat the field list as unverified until the initialiser agrees</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a fact the format <em>checks</em> is trustworthy on its own; a fact it merely <em>stores</em> is trustworthy only under a convention some other component owns. Find out which you are reading before you rely on it.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>"Derived from a field order and therefore unstable" is a hazard this collection has covered three times, and an enum's ordinal is the worst version of it because nothing fails loudly. Compare a <a href="/courses/pe/lessons/pe-imports">PE import by ordinal</a> and a <a href="/courses/coff/lessons/coff-relocations">COFF relocation's symbol ordinal</a>: both are positions, both are resolved by a consumer against a table the producer wrote, and both are checked at use &mdash; an out-of-range ordinal is a load-time or link-time failure. <strong>An enum's ordinal is a position that no consumer resolves, because the consumer computed it once at class initialisation from the field order it read.</strong> The same shape, and none of the safety, which is why the Java rule is "never persist an ordinal" rather than "an out-of-range ordinal will be caught".</p>
                <p>The reflective recovery is a mechanism the format leans on repeatedly, and it is the counterpart to what <a href="/courses/wasm/lessons/wasm-objects">a WebAssembly custom section</a> is for: a place to put information the core format does not model. There the difference is that custom sections are inert data for a tool to read, while here the JDK <em>interprets</em> the flags to build the enum's behaviour. <strong>One is a container the format knows nothing about; the other is a bit the format defines and a library gives meaning to.</strong> The consequence is that an enum's semantics are upgradeable &mdash; a newer <code>java.lang.Enum</code> could add methods without a class file change &mdash; and that is a real architectural choice rather than an accident.</p>
                <p>The two-way nature of the flag tables is a good closing note for this module. <code>0x4000</code> means the same thing in the class table and the field table, and <code>0x0008</code> means different things in the class table and the member table, and <a href="/courses/jvm/lessons/jvm-inner-classes"><code>InnerClasses</code></a> uses the member table for what looks like a class. <strong>Three concepts, three flag tables, and a bit that is ambiguous in one position and not in another</strong> &mdash; which is the Module 2 lesson arriving repeatedly, and the strongest general habit in this course: when a format has more than one kind of record, it has more than one vocabulary, and the values are identical while the meanings are not.</p>
                <p>What the three shapes in this module share is more interesting than how they differ. <strong>A record's components are a declared list. A sealed class's permitted subclasses are a checked list. An enum's constants are a derived list.</strong> Three answers to the same question &mdash; how does the machine learn what a type contains &mdash; on one spectrum from most explicit to least: an attribute the compiler wrote, a list the verifier enforces, a flag a library interprets. And the module is the argument that this spectrum is a real design axis, because all three shapes shipped in the same era and each reached for the mechanism its semantics actually required.</p>
                <p>Module 5 moves from what a type <em>is</em> to how it is <em>connected</em>: <a href="/courses/jvm/lessons/jvm-invokedynamic">the <code>invokedynamic</code> instruction and its bootstrap methods</a>, which is where the class file stopped being a description of code and became a program for <em>producing</em> code at load time.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-sealed">Previous: Sealed Types</a></span>
                <span><a href="/courses/jvm/lessons/jvm-invokedynamic">Next: invokedynamic and Bootstraps</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
