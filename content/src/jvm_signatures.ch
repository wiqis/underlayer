// JVM Course — Module 3: The Attribute Mechanism
// Concept: the Signature attribute — generics as a second, richer type language
// layered on the erased descriptor.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_signatures() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Signature Attribute — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>The Signature Attribute</h1>
            <div class="lesson-meta">20 min &middot; Module 3: The Attribute Mechanism &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A field declared <code>Map&lt;String, List&lt;? extends Number&gt;&gt;</code> has the descriptor <code>Ljava/util/Map;</code>. <strong>The type arguments are gone.</strong> Not encoded elsewhere in the member &mdash; gone from the descriptor, which is the only type the verifier ever sees.</p>
                <p>That is erasure, and it is a language decision rather than a format one: the runtime does not know about type arguments, so the file the runtime checks does not either. A consequence follows immediately. <strong>Two fields with the same descriptor are indistinguishable to the verifier</strong> &mdash; a <code>Map&lt;String,?&gt;</code> and a <code>Map&lt;Integer,?&gt;</code> are the same type as far as any check the JVM performs. Type safety at the container's level is enforced by the compiler inserting casts at the call sites, not by the class file recording what was there.</p>
                <p>So where did the type arguments go? Into a second attribute, with a second grammar, sitting beside the descriptor. <strong>The class file contains two type languages</strong>, and the <a href="/courses/jvm/lessons/jvm-members">descriptor grammar</a> from Module 2 is the one the machine uses while the signature grammar is the one humans and reflection use. Confusing the two is the most common mistake in reading class files, because they look similar and mean different things.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The signature grammar, and the additions to the descriptor grammar it makes. Everything from Module 2 still works &mdash; the eight primitives, <code>L...;</code>, <code>[</code> &mdash; plus six new productions:</p>
                <div class="hex-dump">
                    <pre>  UNCHANGED from the descriptor grammar:

    Z B C S I J F D V           the primitives
    Lname;                      a class
    [X                         an array of X

  ADDED by the signature grammar:

    Tname;                      a TYPE VARIABLE, e.g. T
    &lt;X;...&gt;                       type arguments, e.g. &lt;String;List;&gt;
    .name                       an INNER class, e.g. .Entry
    ^X                         a wildcard: exactly X
    +X                         a wildcard: ? extends X
    -X                         a wildcard: ? super X
</pre>
                </div>
                <p>The wildcards are the part with no descriptor equivalent at all, and they are worth understanding as a group. <strong>There is no way to write "a list of some unknown type" in a descriptor</strong>, because erasure turns <code>List&lt;?&gt;</code> and <code>List&lt;String&gt;</code> into the same <code>Ljava/util/List;</code>. In a signature they are different, and the difference is exactly those three prefixes:</p>
                <div class="formula">
    ^X     ?  exactly X.  Unbounded. The type argument is irrelevant
                    to this use, and that is the point.

    +X     ? extends X.  This use needs no MORE than X.

    -X     ? super X.  This use needs no LESS than X.

  and a bare X, with no prefix, means the argument is EXACTLY X --
  which in a parameter position means an invariant type, and in a
  field means the declared type.
</div>
                <p>Note what a wildcard costs: <strong>one byte, and it changes the meaning rather than adding a type.</strong> There is no wildcard object, no extra indirection, no runtime representation. The whole concept is a compile-time constraint and it costs a prefix character in a string. That is close to the cheapest a language feature can be implemented, and it is a good measure of how much a format can be stretched by adding productions to a grammar rather than adding structures.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>One field, and both of its type descriptions side by side. The source is <code>Map&lt;String, List&lt;? extends Number&gt;&gt; m;</code> and the file records both:</p>
                <div class="hex-dump">
                    <pre>  descriptor: Ljava/util/Map;
  Signature: #18
      Ljava/util/Map&lt;Ljava/lang/String;Ljava/util/List&lt;+Ljava/lang/Number;&gt;;&gt;;

  read the signature as a type:
      Ljava/util/Map        a Map
      &lt;                    type arguments follow
        Ljava/lang/String;   the first: String
        Ljava/util/List      the second: a List
        &lt;                    whose type arguments follow
          +Ljava/lang/Number;  the first: ? extends Number
        &gt;
      &gt;

  and the SAME nesting written in Java source, for comparison:
      Map&lt;String, List&lt;? extends Number&gt;&gt;
</pre>
                </div>
                <p>Two things in that are worth pausing on, and one of them is a difference nobody expects.</p>
                <p><strong>Type arguments are inline, not named.</strong> <code>Ljava/util/List&lt;+Ljava/lang/Number;&gt;;</code> is one <code>Utf8</code> entry containing the whole nested structure. There is no pool index for the inner <code>List</code>, no shared sub-signature, and therefore <strong>no deduplication of a repeated type argument</strong> &mdash; two fields of <code>Map&lt;String,Integer&gt;</code> get two identical signatures, each its own entry. The descriptor grammar has no such nesting so the question does not arise there; here it is a real cost, and it is the price of a grammar that can express an arbitrary type in one string.</p>
                <p>And <strong>the <code>+</code> is doing exactly one thing</strong>: <code>? extends Number</code> became <code>+Ljava/lang/Number;</code>. Drop the plus and it would mean <code>Number</code> exactly, which is a different program. <strong>One byte, and a wildcard becomes an invariant type.</strong></p>
                <p>Now the difference nobody expects, and it is in the <em>class</em> declaration rather than a member. A class declared <code>class Gen&lt;T extends Comparable&lt;T&gt; &amp; Cloneable, V&gt;</code> records its own bound in its signature:</p>
                <div class="hex-dump">
                    <pre>  T t;   field of type variable T
    descriptor: Ljava/lang/Comparable;      &lt;- the ERASED bound
    Signature:  #21                          // TT;
                ^ the signature is just T. The bound is NOT here.

  the BOUND lives on the class, in the class's own Signature:

    class Gen&lt;T extends Comparable&lt;T&gt; &amp; Cloneable, V&gt;
      class signature: &lt;T:Ljava/lang/Comparable&lt;TT;>;:Ljava/lang/Cloneable;TV;>Ljava/lang/Object;
                       |  |                      |  |  |  |                |
                       |  |                      |  |  |  |                +-- superclass, erased
                       |  |                      |  |  |  +------------------- V's bound is Object
                       |  |                      |  |  +---------------------- V, unbounded
                       |  |                      |  +------------------------- T's SECOND bound
                       |  |                      +---------------------------- Ljava/lang/Cloneable
                       |  +--------------------------------------------------- T's first bound
                       +---------------------------------------------------------- the type parameter
</pre>
                </div>
                <p><strong>The class signature declares the type parameters and their bounds; a member's signature only uses the names.</strong> The field <code>T t</code> has the signature <code>TT;</code> &mdash; a single <code>T</code>, referring back to the class's declaration. And the bound <code>Comparable&lt;T&gt;</code> is <em>erased to <code>Comparable</code></em> in the class's own signature even though it appears in full there, because the bound's own type argument is <code>T</code> and a bound cannot itself be parameterised by the thing it bounds.</p>
                <p>That is a subtle and real constraint: <strong><code>&lt;T extends Comparable&lt;T&gt;&gt;</code> records as <code>&lt;T:Ljava/lang/Comparable;&gt;</code></strong> &mdash; the self-reference is dropped. It is a consequence of erasure reaching into the bounds rather than stopping at the type arguments, and it is the kind of detail that makes the grammar worth reading properly rather than pattern-matching.</p>
                <div class="callout callout-warn">
                    <strong>The <code>ampersand</code> in the source became a second colon.</strong> <code>Comparable&lt;T&gt; &amp; Cloneable</code> is <code>:Ljava/lang/Comparable&lt;TT;&gt;:Ljava/lang/Cloneable;</code> in the file. A class header opens with <code>&lt;</code>, each type parameter is a name, then a colon and its bound, and <strong>additional bounds are simply more colons</strong> &mdash; the intersection is implicit in the repetition. No <code>&amp;</code> appears, and there is no count of bounds. That is a genuinely terse encoding of a concept that needs a fair amount of syntax in source, and it is the clearest example in the format of a grammar being more compact than the language it describes.
                </div>
                <h3>Where signatures appear, and where they do not</h3>
                <p>One list, and the absences are as informative as the presences:</p>
                <div class="hex-dump">
                    <pre>  on a FIELD with type arguments        Signature
  on a METHOD with type arguments       Signature
  on a CLASS with type parameters       Signature
  on a METHOD with type PARAMETERS      Signature

  and ABSENT, always, when there is nothing to add:

    a plain int x                descriptor I, no Signature
    a plain String s             descriptor Ljava/lang/String;, no Signature
    a field whose type arguments are all concrete and unchanged
</pre>
                </div>
                <p><strong>A signature is present only when the erased type is a loss.</strong> That is the rule, and it is why most fields in most classes have no signature attribute at all. It is also why the attribute is not derivable: a reader cannot tell from a descriptor whether a signature was omitted because none was needed or because the producer was careless, and only the specification's rule for each descriptor tells you which.</p>
                <p>One exception worth knowing: <strong>generic <em>methods</em> get a signature for their type parameters even when no parameter is generic.</strong> <code>public &lt;R&gt; R conv(T in, Function&lt;T,R&gt; f)</code> has a <code>Function</code> parameter, so it would need one anyway &mdash; but a method that only declares <code>&lt;R&gt;</code> and uses it nowhere generable still gets a signature, because the type parameter itself is information the descriptor cannot carry. The class's version of the same fact: <code>Gen</code> has a signature because it <em>declares</em> <code>T</code> and <code>V</code>, regardless of what its members do with them.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why the file needs two type languages, stated as the reflection query that breaks if you use the wrong one:</p>
                <div class="formula">
  the query:  "what is the declared type of this field?"

    getType() on a Field returns the ERASED type.
      a field declared Map&lt;String, List&lt;? extends Number&gt;&gt;
      returns java.util.Map

    getGenericType() returns the SIGNATURE type.
      the same field returns
      java.util.Map&lt;java.lang.String,
                   java.util.List&lt;? extends java.lang.Number&gt;&gt;

  and the reason both exist:

    erased type   -> what the JVM checks, and what a cast uses
    signature     -> what a compiler or a tool wants to know

  the compiler does NOT use the signature to type-check anything.
  It generates the signature and then type-checks against the ERASED
  types, inserting checkcast instructions at the boundaries.
</div>
                <p>That last line is the part that makes the whole design coherent, and it is a deliberate division of labour. <strong>The signature is documentation that happens to be machine-readable; the descriptor is the contract.</strong> When a generic method's body does <code>String s = list.get(0);</code> on a <code>List&lt;Integer&gt;</code>, the compiler knows from its own analysis that this is wrong, and it rejects the program. If you defeated the compiler &mdash; a bytecode library, or a language that compiles to the JVM without generics &mdash; and emitted the same <code>get</code> followed by an assignment to a <code>String</code> local, the class file would contain no signature saying so, and the JVM would not care, because the erased types are compatible. <strong>Generic type safety in the JVM is a compile-time property enforced by casts, and the file's signature is not part of it.</strong></p>
                <p>Which is worth stating carefully, because it is the opposite of what the attribute's existence suggests. It is entirely possible to write a class file that is <em>wrong</em> about its generics and the JVM will load and run it, inserting a <code>checkcast</code> that throws where a correctly compiled program would not. Compare that with the <a href="/courses/jvm/lessons/jvm-stackmaps">stack map</a>, where a wrong claim is a load-time rejection. <strong>One attribute is checked and one is not, and the difference is that the stack map is load-bearing for safety while the signature is not.</strong></p>
                <p>The practical consequences for anyone building tools are three, and they are the reason this concept is worth a lesson rather than a footnote. A tool that <strong>renames a class</strong> must rewrite descriptors <em>and</em> signatures, or reflection will report the old name. A tool that <strong>reads a field's type</strong> has to choose which of the two it wants, and picking the descriptor by accident is the common bug. And a tool that <strong>checks whether two fields have the same type</strong> must compare descriptors, not signatures &mdash; because two fields with different signatures and the same descriptor are the same type to the machine, and treating them as different is how a verifier-like tool ends up rejecting valid code.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Gen.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Gen.class</code></pre>
                <ul>
                    <li><strong>Compile one generic declaration and read both descriptions.</strong> A <code>List&lt;String&gt;</code> field, and note the descriptor is <code>Ljava/util/List;</code>. <strong>That gap is erasure, and seeing it in a file you made is more convincing than any description of it.</strong></li>
                    <li><strong>Add a wildcard of each kind.</strong> <code>List&lt;?&gt;</code>, <code>List&lt;? extends Number&gt;</code>, <code>List&lt;? super Integer&gt;</code> and <code>List&lt;String&gt;</code>. All four have the same descriptor; the signatures differ by one byte each. <strong>Four programs, one type to the machine, four types to a human</strong> &mdash; and the byte that separates them is the whole concept.</li>
                    <li><strong>Find the self-reference erasure in a bound.</strong> Declare <code>&lt;T extends Comparable&lt;T&gt;&gt;</code> and read the class signature. <strong>The bound appears as bare <code>Comparable</code></strong>, with the <code>T</code> dropped, and working out why is the single most interesting thing in this concept.</li>
                    <li><strong>Prove the attribute is conditional.</strong> Add a plain <code>int</code> field next to a generic one and count the signatures. <strong>One has it, one does not</strong>, and the rule is that a signature exists only when the erased type loses something.</li>
                    <li><strong>Write a signature parser and test it on the nested case.</strong> The <code>Map&lt;String, List&lt;? extends Number&gt;&gt;</code> above is the test: type arguments nest, so a parser that reads one level will mis-handle it. <strong>And note that there is no pool index per nesting level</strong> &mdash; the whole thing is one string, which is what makes a recursive parser necessary.</li>
                    <li><strong>Try to fool the verifier with a wrong signature.</strong> Write a class whose signature claims <code>List&lt;String&gt;</code> while the code puts an <code>Integer</code> in and reads a <code>String</code> out, using a bytecode library to emit it. <strong>Load it and watch where it fails</strong> &mdash; at the <code>checkcast</code>, at run time, not at verification. That is the difference between a checked attribute and an unchecked one, made visible.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a field is declared <code>java.util.List&lt;? super Integer&gt;</code>. What is its descriptor, what is its signature, and what does the JVM actually check when the field is read and assigned to a <code>Number</code>?</p>
                <div class="quiz" id="quiz-jvm-signatures-1">
                    <button class="quiz-option" data-correct="true" data-explain="All three parts follow from erasure, and the third is the one that surprises people. The descriptor is the bare reference type, because a descriptor grammar has no way to express a type argument -- not a wildcard, not a bound, not a concrete type. The signature is that type with a minus prefix, where the minus means the super bound, so the argument position accepts this or a supertype of it. And the third part is the important one: the JVM checks nothing about the generic type. It checks that the field is a List, because that is the descriptor, and the compiler has already inserted a checkcast to Number at the assignment because the source said the assignment should only work if the element really is a Number. The signature is never consulted. It is documentation that happens to be machine-readable, which is why a class file can state a signature that is simply wrong and still load and run, failing later at the cast instead of at verification. Contrast the StackMapTable, where a wrong claim is a load-time rejection, and the reason for the difference is simply that one attribute is load-bearing for safety and the other is not." onclick="checkQuiz('quiz-jvm-signatures-1', this)">Descriptor <code>Ljava/util/List;</code>, signature <code>Ljava/util/List&lt;-Ljava/lang/Integer;&gt;;</code>, and the JVM checks only that it is a <code>List</code> &mdash; the generic type is never checked, and the <code>Number</code> assignment is enforced by a compiler-inserted <code>checkcast</code> at run time</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion is right and the mechanism is wrong in the way this concept exists to correct. The descriptor is the erased type because a descriptor grammar has no production for a type argument at all, not because there is a separate attribute for them. A descriptor is L-name-semicolon, and a signature is the same grammar extended; there is no way to add a type argument to a descriptor without changing what every existing descriptor means. And the encoding is not a nested pair of an erased type plus an index for the arguments: the whole generic type is one inline string, so a repeated type argument is not shared between two fields, it is written out twice. That is a real cost of the grammar and it is the trade the format made for being able to express an arbitrary type in a single self-delimiting string." onclick="checkQuiz('quiz-jvm-signatures-1', this)">Descriptor <code>Ljava/util/List&lt;-Ljava/lang/Integer;&gt;;</code>, with the wildcard inline, and the JVM checks the generic type at verification time using the signature</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a tool that finds every field of a given erased type, across a large codebase, to plan a refactoring. It reads each field's descriptor and matches against <code>Ljava/util/Map;</code>. It works. On one module it reports a field of type <code>Map&lt;String, Integer&gt;</code> as not being a <code>Map</code>. The field's descriptor in the file is unambiguously <code>Ljava/util/Map;</code>, the class is valid, and <code>javap</code> lists it as a <code>java.util.Map</code>. What is the defect, and what is the one-line check that distinguishes it from the alternative explanations?</p>
                <div class="quiz" id="quiz-jvm-signatures-2">
                    <button class="quiz-option" data-correct="true" data-explain="The defect is that the tool is comparing the signature instead of the descriptor, and the one-line check is to print both for the failing field and look at which one lacks the type arguments. That distinguishes this from every alternative in one step, and it is worth doing that way round: the symptom is a field of an obviously-correct type reported as not being that type, which rules out parsing and alignment, and the presence of generics in the failing declaration is the clue. The reason the tool is wrong rather than merely incomplete is that a signature is a different grammar, not a decorated descriptor, and it carries information the descriptor deliberately dropped. Matching on it compares the wrong thing: two fields with the same descriptor and different signatures are the same type to the machine, so a tool matching signatures will call them different types and will also call two identically-generic fields the same type only by luck of how the compiler ordered the pool. The general habit is to know, for every field in a format, which of them the machine acts on, because a format that records a thing for humans and a thing for the machine will happily let you read the wrong one, and nothing will complain since both are well-formed." onclick="checkQuiz('quiz-jvm-signatures-2', this)">The tool is matching the signature rather than the descriptor. Print both for the failing field: the one missing the type arguments is the descriptor, and the one carrying them is the signature. Two fields with the same descriptor and different signatures are the same type to the machine</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real class of bug and the evidence argues against it, though not as decisively as the generics clue does. A parse failure on the signature would be a length or nesting problem, and a nesting problem is exactly what a generic type gives you: the type arguments nest, so a parser that reads one level and then expects a closing bracket will mis-parse Map of List. That is worth ruling out properly, and the way to rule it out is to check whether the failure correlates with nesting depth rather than with the presence of generics, since a class with a non-nested generic would then still fail. But the report says the descriptor in the file is unambiguously the bare form, and the tool's stated job is to match descriptors, so the simplest reading is that it is not reading the descriptor it says it reads. A parse error would also more likely produce a missing field than a field of the right type being reported as a different one." onclick="checkQuiz('quiz-jvm-signatures-2', this)">The tool is mis-parsing the signature's nested type arguments, because the signature grammar nests and a parser that reads one level fails on a Map of a List</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: in a format that records one thing for humans and another for the machine, know which is which before you debug anything &mdash; and when a field of an obviously-correct type is reported as the wrong type, compare both fields side by side before reading any parser.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Two type languages in one file is unusual, and the closest comparison in this collection is <a href="/courses/dwarf/lessons/dwarf-types">DWARF's split between a type's structure and its name</a>. A DWARF <code>DW_TAG_pointer_type</code> has a <code>DW_AT_type</code> naming what it points at, and that name is a string resolved through a lookup rather than written inline. <strong>The difference is who resolves it: DWARF's reference is an index to be followed, and the JVM signature's type arguments are inline text to be parsed.</strong> One deduplicates a repeated type name, the other makes a type expressible in a single self-delimiting string, and the second is what lets a signature be a flat <code>Utf8</code> with no graph to walk.</p>
                <p>Erasure itself is the more interesting connection, because the JVM is not the only format to record less than the source said. <a href="/courses/elf/lessons/common-sections">An ELF <code>.debug_info</code> section is a separate artefact precisely because the machine does not need it</a>, and the DWARF that describes a C++ program's types lives outside the sections the program runs from. The JVM takes the opposite approach &mdash; the generics are <em>in</em> the executable artifact, in an attribute &mdash; which is what makes them available to reflection at run time. <strong>Compare C, where <code>sizeof</code> and the mangled name both erase, and where a debugger cannot recover a template argument without a separate debug section.</strong> The JVM's choice is more informative and it costs an attribute per generic member.</p>
                <p>The wildcard's one-byte encoding connects to something structural rather than grammatical. <a href="/courses/wasm/lessons/wasm-globals">A WebAssembly reference type</a> carries no lifetime, no variance and no type argument &mdash; a <code>funcref</code> is a <code>funcref</code> &mdash; and that is the same trade at a smaller scale: the type system is small enough that the machine can check it quickly, and the richness lives outside. <strong>Java's answer is to keep the rich type in the file and check the small one</strong>, which is why it needs both a descriptor and a signature rather than one richer type. A format with a single type grammar would be simpler to read and would lose either the machine's tractability or the human's information, and the two-grammar design is the price of refusing that trade.</p>
                <p>And the class-signature erasure of a self-referential bound is the point where a grammar stops being a convenience. <code>&lt;T extends Comparable&lt;T&gt;&gt;</code> cannot record the <code>T</code>, because the bound is elaborated before <code>T</code> exists as a type. <strong>That is a real limit of encoding bounds as types</strong>, and it is the same shape as <a href="/courses/dwarf/lessons/dwarf-types">a DWARF type whose definition refers to itself</a> &mdash; in both cases the recursion has to be broken, and each format breaks it in the way its data model allows. Java breaks it by erasure; DWARF breaks it with a declaration and a separate definition. The <code>&amp;</code>-to-colon intersection encoding is the visible consequence of choosing the first.</p>
                <p>Next: <a href="/courses/jvm/lessons/jvm-annotations">annotations</a>, where a second grammar appears for a third reason &mdash; because an attribute has to be able to hold a value of a type that is itself a name, and the encoding has to survive that.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-inner-classes">Previous: Inner Classes and Nests</a></span>
                <span><a href="/courses/jvm/lessons/jvm-annotations">Next: Annotations</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
