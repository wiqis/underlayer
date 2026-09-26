// JVM Course — Module 4: Object Shapes
// Concept: PermittedSubclasses — the simplest attribute in the format, and the
// one place a list in a class file is enforced at load time.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_sealed() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sealed Types — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Sealed Types</h1>
            <div class="lesson-meta">16 min &middot; Module 4: Object Shapes &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every other class shape in this course so far has been about <em>describing</em> something. A record describes its components. An enum describes its constants. Sealing does something else: <strong>it constrains what may exist.</strong> The permitted list is not information about the class; it is a rule about the class's future and about everyone else's.</p>
                <p>That makes it the only attribute in this module that the JVM <em>enforces</em>. A wrong record attribute is inert. A wrong signature is unchecked. A wrong <code>PermittedSubclasses</code> list is a load-time rejection, because the verifier has to check that a class claiming to extend a sealed type is actually on the list &mdash; and it can only do that by reading the list.</p>
                <p>So this is a small attribute with a large job, and the interesting parts are what it deliberately does <em>not</em> say. <strong>It does not say the subclasses exist.</strong> It says who is <em>allowed</em> to be one, and the permitted subclass's own file is what makes it one.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The whole attribute, in its entirety:</p>
                <div class="formula">
PermittedSubclasses, on a sealed class:
    u2 number_of_classes
    then that many u2 CONSTANT_Class indices

  and that is all. Six bytes of structure.
</div>
                <p><strong>This is the shortest meaningful attribute in the format.</strong> No flags, no count of flags, no per-entry structure, no version. Compare <a href="/courses/jvm/lessons/jvm-attributes"><code>Record</code>'s</a> six bytes <em>per component</em>, or <a href="/courses/jvm/lessons/jvm-inner-classes"><code>InnerClasses</code>'s</a> eight. A reader for this attribute is a two-line loop.</p>
                <p>And the shape is worth contrasting with the two attributes it most resembles, because they are byte-identical in layout and mean different things. From <code>Sealed.class</code>:</p>
                <div class="hex-dump">
                    <pre>  PermittedSubclasses:  00 02 00 0a 00 08
                                  |     |     |
                                  |     |     +-- #8  = Sealed$B
                                  |     +-------- #10 = Sealed$A
                                  +-------------- TWO permitted subclasses

  NestMembers:           00 06 00 1b 00 1d 00 1f
                                  |  00 21 00 12 00 07
                                  +-- also a count and a list of u2
</pre>
                </div>
                <p><strong>Identical structure, different meaning, and no way to tell them apart from the bytes</strong> &mdash; which is the <a href="/courses/jvm/lessons/jvm-attributes">escape hatch's</a> property again, and a good one to internalise: the attribute <em>name</em> carries all the semantics and the body carries none. A reader cannot infer that one is about inheritance and the other about access; it has to know which name it is holding.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>What a sealed hierarchy actually looks like in a class file, and the detail that surprises: <strong>the attribute appears on every class in the hierarchy, not just the parent</strong>.</p>
                <div class="hex-dump">
                    <pre>  Sealed.class (the parent)
    PermittedSubclasses -> Sealed$A, Sealed$B
    InnerClasses:
      public static final Sealed$B of class Sealed
      ... one record per permitted subclass, giving each the
          ACC_FINAL | ACC_PUBLIC that sealing implies

  Sealed$A.class
    PermittedSubclasses -> EMPTY (0 bytes of body)
</pre>
                </div>
                <p><strong>An empty <code>PermittedSubclasses</code> is the marker for "sealed and permits nothing further".</strong> That is a real and slightly odd design: the attribute's <em>presence</em> is what says "sealed", and the list can be zero-length. A sealed class permitting no subclasses is legal and means the hierarchy is closed at exactly itself &mdash; and the way to express that is an attribute with an empty body, which is four bytes of header and nothing else.</p>
                <p>This is the opposite of the <a href="/courses/jvm/lessons/jvm-records">record</a> situation, and the contrast is instructive. For a record, the attribute's content is the declaration. For a sealed class, <strong>the attribute's presence is the declaration and its content is a permission list</strong> &mdash; so an empty content is meaningful rather than degenerate, and a reader that checks "is the list non-empty" to decide sealedness gets it exactly backwards.</p>
                <h3>The final flag, and why sealing implies it</h3>
                <p>Every permitted subclass in the sample is <code>public static final</code> in the <code>InnerClasses</code> record. <strong>The <code>ACC_FINAL</code> is not a coincidence and not optional</strong> &mdash; a permitted subclass must be final, because a class that could be extended could be extended by something not on the list, which defeats the entire mechanism.</p>
                <p>That is the one constraint sealing adds to the subclass, and the format enforces it: the verifier rejects a permitted subclass that is not final. <strong>So the two attributes are coupled</strong> &mdash; <code>PermittedSubclasses</code> on the parent permits, and the <code>ACC_FINAL</code> on the child's <code>InnerClasses</code> record seals the permission from propagating. A tool that reads the permitted list and forgets to check the child's flags will report a hierarchy that is not actually closed.</p>
                <p>But a permitted subclass does not have to be a class. <strong>An interface may be permitted, and an interface cannot be <code>final</code></strong> &mdash; so the <code>final</code> rule does not apply there. That is the asymmetry in the rule, and it is derived from the language rather than from the encoding: sealing an interface restricts who may implement it, and implementations are not subtypes in a way that can be further sealed.</p>
                <div class="callout callout-warn">
                    <strong>The list is a claim, and the claim is checked from both sides.</strong> For a permitted subclass to actually be one, <em>both</em> its own file and its parent's must agree &mdash; the parent must list it and the child must declare the parent as its <code>superclass</code>. This is the same two-sided arrangement as <a href="/courses/jvm/lessons/jvm-inner-classes">the nest</a>, and for the same reason: a one-sided claim is just an assertion. Here, though, the failure mode is a compile error rather than a load error, because <code>javac</code> checks both directions and reports "cannot extend sealed class" or "sealed class missing permitted subclass" as source errors. <strong>What the JVM adds is the load-time check, which catches a hand-edited or maliciously edited file that <code>javac</code> would never produce</strong> &mdash; and that check is the reason this attribute is the enforced one.
                </div>
                <h3>Same-package, cross-package, and the module system</h3>
                <p>The language restricts who may be a permitted subclass, and those restrictions are a <em>source</em> rule rather than a format one, but they explain why the file sometimes looks sparse. Two rules at the source level: permitted subclasses must be in the <strong>same package</strong> as the sealed class, or in the same <strong>module</strong> if the sealed class is in one. The second rule is why a sealed class in a named module can permit a class from a different package, and why one in the unnamed classpath cannot.</p>
                <p>Nothing in the six bytes records which rule applied. <strong>The attribute is just a list of names, and the package relationship is a fact about the names</strong> &mdash; which a verifier can only check by loading the referenced classes. So a permitted subclass in a class file that the verifier cannot resolve is a problem at load time, and that is one reason hand-building these hierarchies is fiddly: the parent's file names classes that must exist elsewhere.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What the enforcement is actually for. Sealing exists to let the compiler and the machine reason exhaustively about a type hierarchy &mdash; and the payoff is a <code>switch</code> that is checked at compile time:</p>
                <div class="formula">
  without sealing: a switch over a type is OPEN

    switch on shape:
      case Circle c    -- ...
      case Square s    -- ...

    a new Shape subclass makes this silently wrong.
    the compiler says nothing, because the type is not final
    and the future class may add a case.


  with sealing: a switch over a sealed type is CLOSED

    sealed interface Shape permits Circle, Square, Triangle
    -- (the permits clause IS the PermittedSubclasses attribute)

    switch on shape:
      case Circle c    -- ...
      case Square s    -- ...
      case Triangle t  -- ...

    the compiler now REQUIRES exhaustiveness, because it can
    prove the list is complete.
</div>
                <p><strong>That is the whole reason for the attribute.</strong> Exhaustive switching is a compile-time proof that needs the set of subtypes to be known and finite, and a list of permitted subclasses in a class file is exactly that set. <strong>Without the attribute, the compiler would have to know the hierarchy from the source of every class involved, and a class file would carry nothing that a downstream tool could use</strong> &mdash; and record deconstruction, the feature in the previous concept, would be impossible, because destructuring needs the component list for the same reason exhaustive switching needs the subtype list.</p>
                <p>So both of the newest features rest on the same principle, and it is the principle this module has been building: <strong>the format records what the language's reasoning needs, as a first-class structure, rather than leaving the machine to infer it.</strong> A record's component list and a sealed class's permitted list are the same kind of fact &mdash; an ordered or unordered set of names the compiler must consult &mdash; and they are both things a class file could plausibly have omitted on the grounds that the compiler knows them already.</p>
                <p>And the honest limit, which is where the sealed design is genuinely more constrained than the record one. <strong>Sealing is enforced by the verifier, so a wrong list is a load-time rejection; records are enforced by nothing, so a wrong list is inert.</strong> That asymmetry is a consequence of what each feature is for. Exhaustiveness is a <em>correctness</em> property &mdash; a missed case is a wrong answer at run time &mdash; so the machine checks it. A record's components are a <em>description</em>, and a description the machine does not need cannot be worth a check.</p>
                <p>Compare that to how a comparable constraint is handled elsewhere in this collection. <a href="/courses/pe/lessons/pe-load-config">A PE's <code>GuardCFCheckFunctionPointer</code></a> is a claimed function that the loader verifies before using &mdash; enforcement, not description. <a href="/courses/coff/lessons/coff-weak-externals">A COFF weak external</a> is a claim the linker resolves rather than trusts &mdash; also enforcement. <a href="/courses/wasm/lessons/wasm-types">A WebAssembly module's declared imports</a> must be provided or instantiation fails &mdash; enforcement again. <strong>Whenever a format has a list that constrains what can exist rather than describing what does, it usually checks it, because the list's whole purpose is the constraint.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Sealed.class
$ python3 courses/jvm/assets/samples/crosscheck.py classes/Sealed.class</code></pre>
                <ul>
                    <li><strong>Write the whole attribute in six bytes of reading.</strong> A <code>u2</code> count and a loop. <strong>Then write <code>Record</code>'s reader and see how much longer it is</strong> &mdash; two attributes that a scan reports as similar and a parser treats as nothing alike.</li>
                    <li><strong>Find the empty attribute.</strong> Dump <code>Sealed$A.class</code>'s attributes. <strong>There is a <code>PermittedSubclasses</code> with a body of zero bytes</strong>, and its presence is the only thing saying "sealed, permits nothing". A reader testing for a non-empty list gets this exactly backwards.</li>
                    <li><strong>Remove a <code>ACC_FINAL</code>.</strong> Take a permitted subclass's <code>InnerClasses</code> record and clear its <code>final</code> bit, fixing lengths. <strong>The verifier will reject it</strong> &mdash; and the rejection is the interesting part, because the permitted list still says the same thing. The two attributes are coupled.</li>
                    <li><strong>Add an unpermitted subclass.</strong> Write a class that extends the sealed class without being in the list, compile it (javac refuses) and then emit it with a bytecode library so javac is out of the picture. <strong>Load it and see where the check fires</strong> &mdash; and compare that with a record whose <code>Record</code> attribute you corrupt, which loads fine.</li>
                    <li><strong>Permit an interface and check the flags.</strong> <code>sealed interface S permits Impl</code> with an empty body, and dump both files. <strong>The permitted entry is a class index to an interface and carries no <code>final</code></strong>, because an interface cannot be final &mdash; and working out what stops the interface's implementations from propagating is the interesting part.</li>
                    <li><strong>Compare the two identical six-byte structures.</strong> <code>PermittedSubclasses</code> and <code>NestMembers</code> are the same shape. <strong>Take a reader that dispatches on layout instead of on name and pass it a file containing both</strong> &mdash; it will produce confident, plausible, wrong output, which is the sharpest possible demonstration that the name carries all the meaning.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a class file has a <code>PermittedSubclasses</code> attribute whose <code>attribute_length</code> is 0 &mdash; present, but an empty body. One of its permitted subclasses has a class file whose <code>InnerClasses</code> record gives it <code>ACC_PUBLIC | ACC_SUPER</code> with no <code>ACC_FINAL</code>. The JVM loads the parent. What is true of the hierarchy, and what happens if a tool tries to use it for exhaustive switching?</p>
                <div class="quiz" id="quiz-jvm-sealed-1">
                    <button class="quiz-option" data-correct="true" data-explain="The parent is loaded because nothing about the parent is wrong: a sealed class that permits nothing is legal and is expressed by an attribute with a zero-length body, so the parent's file is valid and loads. The child is a different matter, and the missing final is the load-time failure, because a permitted subclass must be final or the permission propagates to classes that were never on the list. That is the coupling between the two attributes: the parent grants the permission and the child's final flag revokes its ability to grant it onward, and the verifier checks the second. The exhaustion question has a good answer and a bad one, and it is worth being clear which is which. A correct tool reports an incomplete hierarchy, because it can tell the parent is sealed and the list is empty, so a switch over the parent is exhaustive over exactly one case. An incorrect tool assumes the list is complete, reports full exhaustiveness, and will silently miss a subclass that a hand-edited file could introduce. The empty list is not a failure to read -- it is the encoding of a decision, and the reader's job is to distinguish an empty decision from a missing attribute." onclick="checkQuiz('quiz-jvm-sealed-1', this)">The parent is sealed and permits nothing further, so it loads. The child fails to load: a permitted subclass must be <code>ACC_FINAL</code>, and the verifier rejects the missing bit because without it the permission would propagate to unlisted classes. A tool should report the hierarchy as closed over its single subclass</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion about what the hierarchy means is right and the load-time reasoning is wrong, and the difference matters because it inverts the direction of the failure. The missing final is not a property the parent notices. The parent lists the child; the parent is well-formed; the parent loads. The child is the file that is wrong, because it is the child whose InnerClasses record claims the flags and the child's hierarchy is what the verifier checks when it resolves that class. So the practical consequence is that the parent loads and the child does not, which is a more confusing symptom than a single file failing -- a tool that reads the parent's permitted list will try to load a class that cannot be loaded, and will report a link error rather than a format error. The exhaustion answer is also right, and it is the reason the empty-list case is worth being careful about: a non-empty list is what makes a compiler demand exhaustiveness, and an empty one is a real and meaningful statement." onclick="checkQuiz('quiz-jvm-sealed-1', this)">The parent fails to load, because the verifier validates the permitted subclasses listed in <code>PermittedSubclasses</code> against the flags in each child's own file, and a missing <code>ACC_FINAL</code> makes the parent's list invalid</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a code generator that emits a sealed interface and its implementations. It writes the permitted list, and it marks each implementation <code>final</code>. The generated code compiles and the classes load. Then a user writes a subclass of one of the implementations, and the compiler accepts it &mdash; the hierarchy is not actually closed, and the generator's exhaustiveness analysis is wrong. What did the generator have to do differently, and why is the mistake invisible in the files it produced?</p>
                <div class="quiz" id="quiz-jvm-sealed-2">
                    <button class="quiz-option" data-correct="true" data-explain="The generator had to mark the permitted subclasses final in their own files, and the reason it is invisible is that the file it wrote looks complete by every check it performed. The permitted list is present and correct, the children are present and loadable, the hierarchy is genuinely sealed in the sense that the compiler enforces the permitted list -- and all of that is true. What is missing is a second, separate fact: the ACC_FINAL bit on each child's InnerClasses record, which is what stops the permission propagating. The generator wrote a parent that grants permissions and children that do not decline to pass them on, and nothing in the parent's file records that the children were supposed to. That is the structural reason this bug is so easy to write and so hard to see: the coupling is between an attribute in one file and flags in another, and a generator that reasons per-file will check one and not the other. The general habit is to treat a constraint that spans files as a constraint to verify end to end. When a format expresses a rule by pairing something in a producer with something in a consumer, the producer's half is not evidence that the rule holds -- you have to check the consumer's half, because that is the half that enforces it." onclick="checkQuiz('quiz-jvm-sealed-2', this)">It had to set <code>ACC_FINAL</code> on each implementation's own <code>InnerClasses</code> record. The rule is coupled across two files, and the parent looks correct on its own &mdash; so a generator that reasons per-file writes a valid parent and invalid children without noticing</button>
                    <button class="quiz-option" data-correct="false" data-explain="The source-level rule does require the generated code to be marked final, and that is a real thing to get right -- but it is not the defect described here, and the evidence rules it out. The report says the generated code compiles and the classes load, and marking the implementations final is something javac would have enforced or rejected at compile time if the generator had omitted it in the source. So the generated classes are already final at the source level, which means the source is not what is wrong. The bug is in the binary, and it is specifically that a final class can still be extended by a bytecode-level tool, by a proxy generator, or by any framework that does not go through the Java compiler. That is the whole point of the verifier-level check: javac enforces finalness, and the JVM enforces it independently, precisely so that a class file that is not final is rejected no matter how it was produced. A generator that writes class files has to satisfy the JVM's check, not just the compiler's." onclick="checkQuiz('quiz-jvm-sealed-2', this)">It should have marked the implementations <code>final</code> in the generated Java source, since permitted subclasses must be final and the compiler enforces that rule only for source-level declarations</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a format expresses a rule by pairing something a producer records with something a consumer enforces, the producer's half is never evidence that the rule holds. Check the consumer's half, because that is the half that enforces it.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>A list of names that constrains what may exist is one of the oldest ideas in linking, and the format list gives the same guarantee by a different mechanism. <a href="/courses/elf/lessons/visibility">An ELF symbol's binding</a> restricts which kind of reference may name it, and a <a href="/courses/coff/lessons/coff-weak-externals">COFF weak external</a> restricts what happens when the symbol is absent &mdash; <strong>in all three cases a table of names in one file constrains what another file may do, and the constraint is checked rather than trusted.</strong> Compare a bare <code>.string</code> in <a href="/courses/elf/lessons/symbol-table">an ELF string table</a>, which names things but constrains nothing.</p>
                <p>The difference is who does the checking, and it is the same difference as in the previous concept. <strong>A sealed class's list is checked by the JVM when it resolves the hierarchy; a COFF weak external's is checked by the linker</strong> &mdash; and in both cases the check happens in a different file from the one that declares. That is why the <code>ACC_FINAL</code> bug above is invisible to a per-file reader, and it is a general property of any cross-file constraint: <strong>the declaration and the enforcement are in different places, so a tool that checks in one place is checking half of it.</strong></p>
                <p>Exhaustiveness as a compile-time proof has an exact counterpart in <a href="/courses/wasm/lessons/wasm-instructions">WebAssembly's structured control flow</a>, where the requirement that a function's block type and result type line up is checked by validation rather than trusted from the producer. And it has a counterpart in <a href="/courses/pe/lessons/pe-load-config">a PE's guard flags</a>, where the security policy has to be verifiable from the file rather than from the build system's intentions &mdash; <strong>in each case the machine verifies a property because the producer is not necessarily trustworthy.</strong></p>
                <p>The empty-list case is the part of this attribute that has no clean counterpart elsewhere, and it is worth sitting with. <strong>Four bytes of header and zero bytes of body is a complete, meaningful, loadable statement</strong> that this type is closed over itself. Compare an absent attribute, which means "not sealed". The three states &mdash; absent, present-and-empty, present-and-populated &mdash; are all distinct and all meaningful, and only the middle one is a case where the content is not the data. <a href="/courses/elf/lessons/symbol-table">An ELF section header with a zero size</a> is a similar shape: the structure is there and it declares nothing, and both mean something.</p>
                <p>Finally, the "sealed and permits nothing" pattern is the format's clearest case of <strong>the presence of an attribute carrying information its content does not</strong>, and that sits awkwardly beside the escape hatch's usual bargain. The mechanism was designed so a reader could <em>skip</em> a name it did not recognise, on the grounds that skipping is always safe. For a record, skipping loses the component list, which only matters to someone doing reflection. For a sealed class, skipping loses a constraint the verifier is supposed to enforce &mdash; <strong>so this is an attribute a reader cannot safely skip if it is verifying anything</strong>, and that is a real qualification to the "skip unknown attributes" rule that is worth naming rather than glossing.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-records">Previous: Records</a></span>
                <span><a href="/courses/jvm/lessons/jvm-enums">Next: Enums</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
