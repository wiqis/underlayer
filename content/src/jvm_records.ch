// JVM Course — Module 4: Object Shapes
// Concept: the Record attribute and everything the compiler synthesised that
// the source did not say.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_records() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Records — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Records</h1>
            <div class="lesson-meta">19 min &middot; Module 4: Object Shapes &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A record is the first Java class shape that the compiler is <em>required</em> to add members to. Every other class feature so far has either changed how existing members are read or added a <code>final</code> keyword. A record takes a three-line declaration and produces a class file with <strong>nine members, seven of which exist nowhere in the source</strong>.</p>
                <p>That is a design decision about where the language's contract lives. A class's fields are private and its accessors are hand-written, so the file records exactly what was written. A record's fields are private and its accessors are <em>derived from the field list</em>, so the file has to record the field list as a first-class thing &mdash; which is what the <code>Record</code> attribute is for.</p>
                <p><strong>The attribute is not metadata about a record. It is the declaration</strong>, and the accessor methods, the canonical constructor, <code>toString</code>, <code>hashCode</code> and <code>equals</code> are all consequences of it. Take the attribute away and the class stops being a record even though every method is still there. That is a different relationship between source and file than anything else in the format, and it is why the attribute exists rather than being inferred from the field list.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The attribute is a count and a list of components, each of which is a name, a descriptor, and its own attribute list &mdash; the recursive shape from <a href="/courses/jvm/lessons/jvm-attributes">the escape hatch</a>, applied to a member type that did not exist before Java 16:</p>
                <div class="formula">
Record, on the class:
    u2 components_count
    then that many record_component_info:
        u2 component_name_index        a Utf8: the component's name
        u2 component_descriptor_index  a Utf8: its type descriptor
        u2 component_attributes_count
        then that many attributes     &lt;- RECURSION, one level
</div>
                <p>And that is the entire structure. <strong>There is no list of generated methods in it, no flag saying "this is a record", and nothing describing the equals or toString contract</strong> &mdash; the component list is all of it, and everything else about a record follows from the component list plus the rules in the specification.</p>
                <p>Which is a design worth pausing on, because the alternative was obvious. The format could have encoded a record as a class with a boolean flag and a field list, leaving the compiler to infer the rest. Instead it made the component list <em>the</em> declaration, and the components are declared in the attribute <em>and</em> as private final fields. <strong>They appear twice, and the duplication is what makes a record a record</strong> &mdash; drop the attribute and you have a class with the right methods that is not a record.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Three components, twenty bytes, and the raw attribute from <code>Rec.class</code>:</p>
                <div class="hex-dump">
                    <pre>  Record: 20 bytes
    00 03                    THREE components
  |  +-- 6 bytes each: name, descriptor, attributes_count

  00 0e 00 0f 00 00        "x"    "I"                    0 attributes
  00 12 00 13 00 00        "name" "Ljava/lang/String;"   0 attributes
  00 16 00 17 00 00        "data" "[J"                   0 attributes

  arithmetic: 2 + 3 * 6 = 20.  Exactly the length.
</pre>
                </div>
                <p>Now the class those components describe, and the gap between the source and the member table:</p>
                <div class="hex-dump">
                    <pre>  SOURCE                              FILE
  --------                           ----------
  record Rec(int x,                    public final class Rec
            String name,               extends java.lang.Record
            long[] data)               -- body elided --

                                       private final int x;
                                       private final String name;        &lt;- 3 declared
                                       private final long[] data;

                                       public Rec(int, String, long[]);  &lt;- 1 canonical ctor

                                       public final String toString();   &lt;-
                                       public final int hashCode();      &lt;- 3 from Object
                                       public final boolean equals(Object);

                                       public int x();                    &lt;-
                                       public String name();              &lt;- 3 accessors
                                       public long[] data();
</pre>
                </div>
                <p><strong>Nine members from three source declarations.</strong> And the accessors are not marked synthetic &mdash; their flags are <code>0x0001</code>, plain public, not <code>ACC_SYNTHETIC</code>. That is a deliberate and slightly surprising choice, and it has a concrete reason: a record's accessors are part of the <em>public API surface</em> that reflection and the language itself depend on. <code>obj.x()</code> in source compiles to <code>invokevirtual x</code>, and if the method were synthetic the compiler would need to know it exists by some other route. <strong>The accessor is real; only the constructor and the three Object overrides are marked differently.</strong></p>
                <p>The class flags are <code>0x0031</code> &mdash; <code>ACC_PUBLIC | ACC_FINAL | ACC_SUPER</code>. <strong>There is no <code>ACC_RECORD</code>.</strong> That is worth stating because it is a natural assumption and it is wrong: the format does not have a record flag, because the <code>Record</code> attribute is the marker. A reader detecting a record looks for the attribute, and a class that somehow acquired the methods without the attribute is not a record &mdash; it is a final class that happens to look like one, and the language will treat it as a normal class.</p>
                <div class="callout callout-warn">
                    <strong>And the superclass is the other half of the trick.</strong> <code>Rec extends java.lang.Record</code> &mdash; every record's superclass is <code>java.lang.Record</code>, and <strong>that is enforced by the JVM, not by the compiler</strong>. A class file claiming to be a record with a different superclass is rejected at load. The reason is a <code>protected</code> constructor: <code>java.lang.Record</code>'s only constructor is <code>protected Record()</code>, so no class other than <code>Record</code> itself or one of its subclasses can call it. A record is a subclass of <code>Record</code> and the only such subclass, which is what stops anyone else from being a record. <strong>The language expresses "this is a record" by inheritance plus one attribute, and the class hierarchy is what makes the attribute unforgeable.</strong>
                </div>
                <h3>The component that can carry an attribute</h3>
                <p>All three components here have <code>attributes_count = 0</code>, which is the common case. The recursion exists for one reason, and it is the same one <a href="/courses/jvm/lessons/jvm-signatures">the <code>Signature</code> attribute</a> was introduced for: a generic component.</p>
                <p><code>record Box&lt;T&gt;(T value, List&lt;String&gt; tags)</code> with an empty body produces a component whose <code>attributes_count</code> is 1, holding a <code>Signature</code>, because the descriptor of <code>List&lt;String&gt;</code> is <code>Ljava/util/List;</code> and the type argument has to go somewhere. So a record component is a position that needed a type-signature, and the <a href="/courses/jvm/lessons/jvm-attributes">escape hatch's</a> answer was to give components their own attribute list rather than widen the component structure. <strong>Had the format added a signature field to the component instead, the change would have been a structural edit; adding an attribute list is the additive change the mechanism was built to allow.</strong></p>
                <p>It also means a component can be annotated &mdash; <code>@NonNull String name</code> produces a <code>RuntimeVisibleAnnotations</code> on the component. That is a genuinely newer position (Java 16 for the component itself, 8 for type annotations that finally had somewhere to go) and it is a good demonstration that the mechanism scales: <strong>three of the five attribute positions were added after the format shipped, and none of them changed the file's shape.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What the attribute buys, told as the question it answers. A record is the format's clearest case of <strong>a declaration the machine reads directly</strong> rather than one the machine infers:</p>
                <div class="formula">
  the record pattern, and what a reflection-based tool does with it

    BEFORE records: match an object's properties by name
      iterate accessors, compare names case-insensitively
      "getName" / "name" / "getname" all plausible
      each component needs its own hand-written code

    WITH records: the Record attribute IS the component list
      for each component: the field IS the component
      read the field directly
      the accessor is guaranteed to exist and to be the field's value

    and the pattern-matching switch (Java 21) needs this to be a FILE
    fact, not a language one:

      switch on obj:
        case Rec(int x, String name, long[] data)  -- one binding per
                                                        component, in order

    compiles to: read the Record attribute, get component N, call
                 component N's accessor, bind to the local N
</div>
                <p><strong>That last line is the point.</strong> Record deconstruction in <code>switch</code> and in <code>instanceof</code> is not something the compiler could implement by convention &mdash; the compiler generates a <code>getfield</code> per component, and it needs to know the component order, which is a fact about the class. So the format needs the component list to be a real, ordered, machine-readable thing rather than something inferred from the order of private final fields, which reflection cannot order reliably and which the class file does not otherwise guarantee.</p>
                <p><strong>The attribute's existence is what makes the pattern feature implementable at all</strong>, and the history runs the right way round: the language feature and the format feature arrived together, with the format designed for it. Compare the other two shapes in this module &mdash; a sealed type's permitted subclasses and an enum's constants &mdash; where the same design principle appears: <strong>each is a first-class list in the file, and the generated members are consequences of it.</strong></p>
                <p>And the cost of that choice, honestly. A record component is declared twice &mdash; as a private final field and in the attribute &mdash; so a rewriter that renames a component must change both, and one that adds or reorders a field has to rebuild the attribute. <strong>Compare a plain class, where the field list is the only declaration and there is nothing to keep in sync.</strong> The duplication buys the language a machine-readable ordered component list, and it costs a tool that edits class files an invariant to maintain. That is a real trade and it is the kind every format makes when it chooses what the machine will need to read directly.</p>
                <p>One detail that catches people: the <code>long[] data</code> component's descriptor is <code>[J</code>, and <code>long</code> takes <a href="/courses/jvm/lessons/jvm-code">two local slots</a> in a frame while its component occupies <strong>one field and one attribute entry</strong>. The two-slot rule is a property of the <em>frame</em> layout, not of the type, and a record component is a field. So a <code>record R(long a)</code> with an empty body has a component with descriptor <code>J</code> &mdash; a single field &mdash; while its canonical constructor's <code>max_locals</code> accounts for two slots. Same type, two different accounting rules, because they are accounting for different things.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Rec.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Rec.class</code></pre>
                <ul>
                    <li><strong>Count the members.</strong> Three source declarations produce nine members. <strong>List which seven and decide for each whether it is marked <code>ACC_SYNTHETIC</code></strong> &mdash; and notice that the three accessors are not.</li>
                    <li><strong>Delete the <code>Record</code> attribute by hand.</strong> Fix every length. <strong>The class still has all nine methods and still runs, but it is no longer a record</strong> &mdash; the pattern-matching <code>switch</code> stops compiling against it. That is the clearest demonstration that the attribute is the declaration rather than a description of it.</li>
                    <li><strong>Change a record's superclass.</strong> Point it at <code>java/lang/Object</code> instead of <code>java/lang/Record</code>, fixing the pool and every reference. <strong>It will be rejected at load</strong>, and the <code>protected</code> constructor in <code>java.lang.Record</code> is the reason why.</li>
                    <li><strong>Make a component generic and find the attribute.</strong> <code>record Box&lt;T&gt;(T value, List&lt;String&gt; tags)</code> with an empty body. <strong>One component now has <code>attributes_count = 1</code></strong> holding a <code>Signature</code> &mdash; the recursion paying for itself, and the reason the component carries attributes at all.</li>
                    <li><strong>Annotate a component.</strong> <code>record R(@Deprecated String name)</code> with an empty body, and find the <code>RuntimeVisibleAnnotations</code> on the component. <strong>That is the fifth attribute position, added long after the format shipped, with no change to the file's structure</strong> &mdash; which is the escape hatch's thesis as a single observation.</li>
                    <li><strong>Compare the <code>long</code> accounting.</strong> <code>record R(long a)</code> with an empty body &mdash; the component descriptor is <code>J</code> (one field) and the canonical constructor's <code>max_locals</code> counts two slots. <strong>Write down both numbers and explain why they differ</strong>; it is the two-slot rule applied to frames and not to fields.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a class file has a private final field <code>int x</code> with descriptor <code>I</code>, a public method <code>int x()</code> with descriptor <code>()I</code>, a public final <code>toString()</code>, a public final <code>hashCode()</code>, a public final <code>equals(Object)</code>, and a public constructor <code>(I)V</code> &mdash; but no <code>Record</code> attribute. Does the language treat it as a record, and how would a tool tell?</p>
                <div class="quiz" id="quiz-jvm-records-1">
                    <button class="quiz-option" data-correct="true" data-explain="No on both counts, and the reason is the distinction this concept is built around. The Record attribute is the declaration, not a description: the language decides a type is a record by the presence of that attribute, and the generated members are consequences of it rather than the criteria for it. A class with all the right methods is a final class that happens to look like a record, and pattern-matching switch will not compile against it, because deconstruction needs an ordered component list to bind to and finds no attribute to read. The tool detects a record the same way, by looking for the attribute, and that is also how a reader knows to trust the component order. There is a second gate the JVM enforces for free, which is worth mentioning because it shows the format is not relying on convention: the superclass must be java.lang.Record, whose only constructor is protected, so a class other than Record or its legitimate subclass cannot claim the hierarchy. The honest reading of the case is that the file looks exactly like a record and is one only by a single attribute's presence." onclick="checkQuiz('quiz-jvm-records-1', this)">No. The <code>Record</code> attribute is the declaration &mdash; the language and every tool detect a record by its presence, and a class with the right methods but no attribute is a final class that looks like one. The verifier enforces a second gate: the superclass must be <code>java.lang.Record</code>, whose constructor is <code>protected</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the plausible inference and it is wrong in a way worth being precise about, because the case was built to make it tempting. The methods are not a reliable test: a final class can declare toString, hashCode and equals, a private field, and a public accessor of the same name, and there is nothing in that combination the format recognises. More decisively, the reason it fails is a positive requirement rather than a negative one -- the language needs an ordered component list to destructure, and the only place a component list exists is the attribute, so a class without it has nothing to destructure even if a tool guessed the component order from the fields. Guessing would also be unsafe, because field order is not guaranteed to be component order and a tool that inferred it could be wrong silently. The attribute is not redundant with the methods; it is the only authoritative statement of what the components are." onclick="checkQuiz('quiz-jvm-records-1', this)">Yes. A record is identified by having private final fields with matching public accessors plus the <code>toString</code>, <code>hashCode</code> and <code>equals</code> overrides, so a tool can detect it structurally without reading the attribute</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a bytecode library that generates a record class. It emits the three private final fields, the three accessors, <code>toString</code>, <code>hashCode</code>, <code>equals</code> and the canonical constructor. The class loads, all methods work, and pattern-matching <code>switch</code> against it fails to compile with "not a recordable class". Compilation with <code>javac</code> produces a working record, so the difference is in the file. You diff the two class files attribute by attribute. What is missing, and why does its absence not affect anything else about the class?</p>
                <div class="quiz" id="quiz-jvm-records-2">
                    <button class="quiz-option" data-correct="true" data-explain="The missing piece is the Record attribute, and the reason it is inert everywhere else is precisely that it is a declaration rather than a description. Nothing in the JVM's execution path reads it: the verifier does not need it, the interpreter does not execute it, and none of the nine methods refers to it. But the language's record pattern needs an ordered component list to destructure, and the attribute is the only place that list exists. So the class is entirely functional as a class and entirely unusable as a record, which is a genuinely odd state -- everything works except the one feature the shape was introduced for. The reason the omission is so easy to miss is that the generated methods are all correct and individually testable, and a test suite that exercises them passes completely. The general habit this points at: when a format uses an attribute as a declaration, the attribute is not redundant with the data it summarises, and a generator that produces the summary without the declaration produces something that looks complete and is not. The corresponding check on the writer side is to diff a real javac output against your own before assuming your members are right, because javac's members are the consequences and yours are the causes." onclick="checkQuiz('quiz-jvm-records-2', this)">The <code>Record</code> attribute is missing. It is inert at run time &mdash; nothing in the JVM reads it &mdash; but the language's record pattern needs the ordered component list that only the attribute provides, so the class works as a class and fails only at the feature the shape exists for</button>
                    <button class="quiz-option" data-correct="false" data-explain="The evidence rules this out. A wrong superclass is not inert: the verifier rejects it at load with a specific error, and the failure would be total rather than partial, so the class would not load at all. The report says the class loads and every method works, which means the hierarchy is already correct -- and the library emits all nine members, so the canonical constructor is present too. Since all nine members are present and the class loads, the only remaining difference between the two files is the attribute, which is a strong argument by exhaustion. The deeper point is the same one the correct answer makes: there are two independent gates on being a record, the attribute and the superclass, and the superclass gate is checked eagerly by the verifier while the attribute gate is checked lazily by the compiler only when a pattern match is attempted. That asymmetry is why the failure is partial and easy to miss." onclick="checkQuiz('quiz-jvm-records-2', this)">The superclass is wrong &mdash; a record must extend <code>java.lang.Record</code>, and without that inheritance the language does not consider the type a record even if every generated member is present</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a format uses an attribute as a <em>declaration</em> rather than a description, the attribute is not redundant with the data it summarises. Generate the consequences and you have something that looks complete and is not.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Three attributes in a row that are all first-class lists, and that is a pattern rather than a coincidence. The <code>Record</code> components, <a href="/courses/jvm/lessons/jvm-sealed">the <code>PermittedSubclasses</code> indices</a>, and the <a href="/courses/jvm/lessons/jvm-enums">enum constants behind <code>ACC_ENUM</code></a> are each a list the machine reads directly, and in each case the compiler generates members as consequences. <strong>Compare a plain class, where the field list is the only declaration and the accessors are the programmer's problem</strong> &mdash; the JVM never has to know which fields are conceptually related, because nothing depends on it.</p>
                <p>That is the same division this course has drawn twice before, in <a href="/courses/dwarf/lessons/dwarf-standard-opcodes">DWARF's <code>DW_TAG_</code> namespace</a> and in <a href="/courses/pe/lessons/pe-data-directories">a PE's data directories</a>. DWARF has a <code>DW_TAG_structure_type</code> whose children are the members, because a debugger needs to know the members as a group; a PE's import directory is a table rather than scattered descriptors, because the loader needs to walk it. <strong>When the machine must relate things, the format makes the relation a structure; when it must not care, the data stays flat.</strong> A record's components are a structure precisely because record deconstruction needs the relation to be readable.</p>
                <p>The duplicate declaration &mdash; field and component &mdash; has a counterpart in every format that lets a machine infer structure. <a href="/courses/coff/lessons/coff-section-table">A COFF section header</a> restates, per section, what the object header summarises, and <a href="/courses/elf/lessons/section-header-table">an ELF section header</a> does the same in a file whose primary structure is segments. <strong>Repetition is the price of letting two readers with different needs find what they need in different places</strong>, and here the two readers are the JVM (which needs the fields) and the compiler (which needs the ordered components).</p>
                <p>And the <code>java.lang.Record</code> superclass is a different kind of device entirely, and it is worth noticing how the format uses inheritance for something it could have used an attribute for. <strong>The format needed "only records can be records" to be true, and it got that from a <code>protected</code> constructor rather than from a check</strong> &mdash; the same way <a href="/courses/jvm/lessons/jvm-sealed">a sealed class</a> gets its exclusivity from the verifier checking the permitted list, and unlike it. A class hierarchy already has the property "a subclass had to call a superclass constructor"; making that constructor <code>protected</code> is a two-word change that gets the whole constraint. <strong>Using an existing mechanism rather than adding a check is the cheaper design whenever it works</strong>, and it is the reason there is no <code>ACC_RECORD</code> flag.</p>
                <p>Next: <a href="/courses/jvm/lessons/jvm-sealed">sealed types</a>, which is the shortest attribute in the format and the one place where the machine enforces something at load time on the basis of a list it reads from a class file.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-annotations">Previous: Annotations</a></span>
                <span><a href="/courses/jvm/lessons/jvm-sealed">Next: Sealed Types</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
