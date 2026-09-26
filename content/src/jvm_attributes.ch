// JVM Course — Module 3: The Attribute Mechanism
// Concept: the attribute escape hatch — one generic shape, and how a format
// with no section table absorbed twenty years of features.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_attributes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Escape Hatch — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>The Escape Hatch</h1>
            <div class="lesson-meta">21 min &middot; Module 3: The Attribute Mechanism &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The <a href="/courses/jvm/lessons/jvm-header">header concept</a> made a point that looked like a limitation: the class file has no section table, no id byte, no way to add a new top-level block. Everything is at a fixed position, and a reader that meets something unfamiliar has nowhere to put it.</p>
                <p>And yet the format has absorbed generics, lambdas, enums, annotations, inner-class access, records, sealed types, modules, and varargs &mdash; features nobody foresaw, several of which changed the language's semantics. <strong>All of that went in through one 8-byte header that is repeated everywhere: a name index and a length.</strong></p>
                <p>This concept is about that header, because it is the most consequential design decision in the format and it is almost invisible. <strong>An attribute is the only part of a class file a reader is allowed to skip without understanding.</strong> That single permission is what made the format extensible, and it is why the class file version could be pinned to the Java release number rather than moving on its own.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Every attribute in the format, without exception, has this shape:</p>
                <div class="formula">
attribute_info:
    u2 attribute_name_index      a pool index naming the attribute
    u4 attribute_length          how many bytes of body follow
    u1 info[attribute_length]    the body, and THE BODY'S SHAPE IS ITS OWN
</div>
                <p>Six bytes of overhead and a length-delimited body whose structure the attribute itself defines. That is the whole mechanism, and the last line is the part that catches people: <strong>there is no common body format.</strong> There is not even a common first field. Verified on four attributes in this course's own samples:</p>
                <div class="hex-dump">
                    <pre>  SourceFile             4 + 2 bytes      the body is ONE u2: a Utf8 index

  NestHost                 4 + 2 bytes      also ONE u2 -- no count, no list

  PermittedSubclasses      4 + 4 bytes      u2 count, then that many u2 indices
      00 02 00 0a 00 08            count 2, then #10 and #8

  NestMembers              4 + 12 bytes     u2 count, then that many u2 indices
      00 06 00 1b 00 1d 00 1f
            00 21 00 12 00 07      count 6, then six indices

  Record                  4 + 20 bytes     u2 count, then per component:
                                          u2 name, u2 descriptor, u2 attrs_count
      00 03 00 0e 00 0f 00 00      count 3
            00 12 00 13 00 00         "x"    "I"
            00 16 00 17 00 00         "name" "Ljava/lang/String;"
</pre>
                </div>
                <p><strong>Every one of those bodies is a different shape, and a reader that guessed would be wrong on at least one.</strong> <code>SourceFile</code> and <code>NestHost</code> are a bare index with no count &mdash; treating them as a counted list reads the following attribute's name index as a count. <code>PermittedSubclasses</code> and <code>NestMembers</code> look identical and mean different things, one naming classes a type may be extended by and the other naming classes inside a nest. And <code>Record</code> nests a third level, because a component can itself carry attributes.</p>
                <p>That is the cost of the design, and it is worth being honest about: <strong>the format gives you a container and no contents.</strong> A tool that wants to read <code>RuntimeVisibleAnnotations</code> must implement the annotation grammar, and there are roughly forty attribute bodies to implement before it understands the format. Compare <a href="/courses/pe/lessons/pe-data-directories">a PE data directory</a>, where adding a table means adding a directory entry and the loader finds it by index &mdash; and compare <a href="/courses/wasm/lessons/wasm-objects">a WebAssembly custom section</a>, which is the same escape hatch with the same property.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Where the attributes appear, and that is not a single place. <strong>There are five distinct places an attribute can appear</strong>, and they are not interchangeable:</p>
                <div class="hex-dump">
                    <pre>  on the CLASS              SourceFile, InnerClasses, NestHost,
                                       NestMembers, Signature, Record,
                                       PermittedSubclasses, BootstrapMethods,
                                       RuntimeVisibleAnnotations, Deprecated,
                                       Module, EnclosingMethod

  on a FIELD               ConstantValue, Signature, RuntimeVisibleAnnotations

  on a METHOD              Signature, Exceptions, Deprecated,
                                       RuntimeVisibleAnnotations, AnnotationDefault,
                                       MethodParameters

  INSIDE a Code attribute  LineNumberTable, LocalVariableTable, LocalVariableTypeTable,
                            StackMapTable, RuntimeVisibleTypeAnnotations
                                       -- and these nest one level deeper
                                       than everything else

  on a Record COMPONENT    Signature, RuntimeVisibleAnnotations
</pre>
                </div>
                <p>That fourth row is the one that costs a reader work, and the previous concept already hit it. <strong>A method's attributes are siblings of its <code>Code</code> attribute, but a method's <em>code</em> attributes are nested inside <code>Code</code></strong> &mdash; because a line number or a stack map is meaningless without the code it describes. So "read a method" means two attribute lists at different depths, and a reader that treats them as one will read the code's nested attributes as the method's and desynchronise.</p>
                <p>And the fifth row is newer than the format's original design. A record component carries attributes, which means the attribute mechanism is <strong>recursive</strong>: a record component's attribute can be a <code>Signature</code>, which is a <code>Utf8</code> index, but the structure around it is the same container. The recursion terminates because the body formats do not themselves contain attribute lists at arbitrary depth &mdash; only <code>Record</code> and <code>Code</code> nest, and both are one level.</p>
                <h3>Why a name and not a number</h3>
                <p>The six bytes of overhead are a pool index and a length, and the choice of a <em>name</em> rather than a number is what makes the mechanism work. An id would be smaller &mdash; two bytes either way, so actually no saving &mdash; but it would need the specification to allocate it, and the specification cannot allocate an id for a feature that does not exist yet. A name needs no permission.</p>
                <div class="formula">
  why a NAME, not an id:

    with an id:    the spec must define the id BEFORE anyone can emit
                   the attribute. Two compilers disagree, or a compiler
                   is newer than the spec, and the reader has no way to
                   know what it is looking at.

    with a name:   anyone can define an attribute, emit it, and a
                   reader that does not recognise the string SKIPS it
                   using attribute_length and carries on.

    the price:     24 attribute-name Utf8 entries in a 24-sample corpus
                   that all use fewer than a dozen distinct names. The
                   dictionary is paying for itself, but not by much.
</div>
                <p>That last line is measurable, and it is worth measuring because it is the format's only recurring overhead. Across the twenty-four class files in this course's samples, the constant pool contains <code>SourceFile</code> twenty-four times, <code>InnerClasses</code> fourteen, <code>NestHost</code> eight, <code>BootstrapMethods</code> four, <code>Signature</code> three, <code>Record</code> three, and one or two of most others. <strong>The name is a <code>Utf8</code> entry and the pool deduplicates identical strings</strong>, so twenty-four classes cost one <code>SourceFile</code> string, not twenty-four. The dictionary earns its keep here exactly as it does for class and method names.</p>
                <div class="callout callout-warn">
                    <strong>And the skip is unconditional, which is the security-relevant part.</strong> A reader that meets an unrecognised attribute does not need permission, does not need a version check, and does not need the attribute to be safe &mdash; it reads <code>attribute_length</code> and steps over that many bytes. There is no way for a new attribute to make an old reader misparse the file, because the old reader never interprets the body. <strong>Compare that with a new <em>instruction</em> opcode, which the verifier must understand or reject the whole class</strong>, and with a new class file version, which the loader refuses outright. The format is closed where it executes and open where it describes, and that split is the single most important thing to understand about how it grew.
                </div>
                <h3>What the reader still has to do</h3>
                <p>Skipping is easy; <em>noticing</em> is not, and a real tool has to do three things a skipping reader does not. It has to collect the distinct attribute names across a whole corpus to know which bodies to implement. It has to reject a <em>malformed</em> body of a name it <em>does</em> recognise, because the skip rule means an unrecognised body is invisible but a recognised one with a bad length is a real error. And it has to know which of the five positions an attribute is legal in, because the JVM does check that: <strong>a <code>ConstantValue</code> attribute on a method is rejected, and so is a <code>LineNumberTable</code> outside a <code>Code</code></strong>.</p>
                <p>That last check is the one a hand-rolled reader discovers the hard way, and it is a good example of the difference between "can skip" and "may be present". The format has a table of which attribute names are valid in which of the five positions, and the specification is the only place that table exists &mdash; <strong>it cannot be derived from the bytes, because a class file with a <code>ConstantValue</code> on a method is not malformed, it is illegal, and only a reader that knows the table can tell the difference.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a tool that wants to be useful has to implement, and the ordering that makes it possible. The lists are measured, not guessed:</p>
                <div class="formula">
  class-level attributes seen across this course's 24 samples:

    SourceFile                  24    on every single class
    InnerClasses                14
    NestHost                     8
    BootstrapMethods             4
    Signature                     3
    Record                        3
    NestMembers                   3
    RuntimeVisibleAnnotations     2
    EnclosingMethod               2
    PermittedSubclasses           1

  code-level attributes:

    LineNumberTable             75    on every Code attribute, always
    Signature                    11
    StackMapTable                 4
    AnnotationDefault             2
                </div>
                <p>Two things fall out of those numbers, and both are about what is optional.</p>
                <p><strong><code>LineNumberTable</code> appears on all 75 <code>Code</code> attributes without exception</strong>, because <code>javac</code> emits debug information by default. That means a class file is systematically larger for being debuggable, and the flag that turns it off (<code>-g:none</code>) removes a nested attribute from every method at once. <strong>It also means the attribute is present by default and its absence is the unusual case</strong> &mdash; which inverts the intuition from a native format, where line tables are in a separate section and are usually stripped from a release build.</p>
                <p>And <strong><code>SourceFile</code> is on all 24 classes</strong>, which sounds like padding until you remember what it costs: a two-byte body, and the <code>SourceFile</code> string is a pool entry that only exists because of it. <strong>Remove <code>SourceFile</code> and the pool shrinks, because the source filename was never referenced by anything else in the file</strong> &mdash; the class file does not need to know its own name. A stack trace can therefore name a class it cannot locate on disk, which is exactly what happens with obfuscation, and it is a small illustration that a format's contents are driven by what something needs rather than by what a human might expect to find.</p>
                <p>That gives the shape of a real implementation. <strong>Collect the names first, then implement bodies in order of how often they occur</strong> &mdash; which for a general tool means <code>Code</code> and <code>SourceFile</code> and <code>LineNumberTable</code> first, because those cover essentially every class, and the exotic ones last or never. A tool that skips unknown attributes will still load every class ever compiled; a tool that only <em>understands</em> known ones and errors otherwise will fail on the first class from a newer compiler. <strong>Skipping is the behaviour that makes a reader future-proof, and it is available for free.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Rec.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Rec.class</code></pre>
                <ul>
                    <li><strong>Write the skipper before any parser.</strong> Six bytes of header and a jump. Run it over every class in the JDK's <code>lib</code> directory and confirm it never desynchronises. <strong>That is the whole extensibility mechanism, and it is a dozen lines</strong> &mdash; write it before you write anything else and every attribute you do not understand costs you nothing.</li>
                    <li><strong>Confirm the no-common-shape claim.</strong> Take <code>SourceFile</code>, <code>NestHost</code>, <code>PermittedSubclasses</code> and <code>Record</code> and write a reader that assumes they are all counted lists. <strong>Watch <code>SourceFile</code> read the next attribute's name index as a count</strong>, and work out what number it produces and why it looks plausible.</li>
                    <li><strong>Find the illegal-but-well-formed case.</strong> Move a <code>ConstantValue</code> attribute from a field to a method by hand, fixing every length. <strong>It will be structurally perfect and the JVM will still reject it</strong>, and the rejection is the only thing that reveals the position table exists.</li>
                    <li><strong>Count the attribute names in a large corpus.</strong> Take every class file you can find and tally the distinct attribute names against the total number of attribute occurrences. <strong>The ratio is the constant pool's dictionary earning its keep</strong>, and it is the same trade the pool makes for class names.</li>
                    <li><strong>Measure the <code>-g:none</code> difference.</strong> Compile something with and without it and compare file sizes and attribute counts. <strong>All 75 <code>Code</code> attributes here carry a <code>LineNumberTable</code> by default</strong>, and seeing what that is worth in bytes makes the nesting feel less like free.</li>
                    <li><strong>Write an unknown attribute and watch it be skipped.</strong> Append a hand-built attribute with a name nobody has heard of, sized correctly, to a class. <strong>Every reader should load the class without complaint</strong>, and that is the escape hatch demonstrated rather than described.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a class file has a <code>SourceFile</code> attribute whose body is 2 bytes, followed immediately by a <code>Deprecated</code> attribute. A reader that assumes every attribute body is a counted list of two-byte entries will do what, and why will nothing tell it is wrong?</p>
                <div class="quiz" id="quiz-jvm-attributes-1">
                    <button class="quiz-option" data-correct="true" data-explain="This is the sharpest practical consequence of the format giving you a container and no contents. The reader reads SourceFile's name index and length, steps over the two-byte body correctly, and arrives at the Deprecated attribute. But if it then treats SourceFile's body as a counted list it reads the first two bytes of the body as a count. Those two bytes are the Utf8 index of the source filename, and a pool index is a small number, so the reader believes there are that many entries and starts consuming two bytes at a time from whatever follows. In this case that means it walks into the next attribute's header, treats attribute_name_index as an entry, and attribute_length as another entry, and carries on from a position that is wrong by a multiple of two. The reason nothing reports it is the property the whole mechanism is built on: a reader is allowed to skip an attribute it does not understand, so a misparse of a body it did not check produces output that still looks like a valid attribute table. The end-of-file check would eventually catch it, which is the argument for always doing that check, but the parse itself has no way to object. And the deeper point is that there is no common body format to get wrong, because the format deliberately does not define one." onclick="checkQuiz('quiz-jvm-attributes-1', this)">It reads the filename's pool index as a count, then consumes two bytes at a time from the following attribute's header, and nothing reports it because the reader is permitted to skip bodies it does not understand &mdash; so a misparse still yields a structurally plausible attribute table</button>
                    <button class="quiz-option" data-correct="false" data-explain="The desynchronisation is real and the conclusion about detection is not. A reader that walks the wrong number of bytes ends up at the wrong position, and while the format does permit skipping an unrecognised body, it does not permit ignoring a length field: attribute_length is how every reader finds the next attribute, so a reader that has lost track of position cannot find the next boundary by skipping and will end up consuming a later attribute's length as data. That is caught by the end-of-file assertion, which every reader in this course performs, and it fails loudly. So the misparse is detected, just later and less specifically than it would be if the reader had a way to know what a body should look like. The reason nothing objects at the point of the mistake is that the bytes are individually plausible, not that the format tolerates the error." onclick="checkQuiz('quiz-jvm-attributes-1', this)">It reads the filename's pool index as a count and desynchronises, and the JVM rejects the class at load time with a specific error naming the malformed attribute, so a reader never gets far enough to be fooled</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a class file inspector for a build tool. It must handle every class a large project compiles, including classes from dependencies built years apart with different compiler versions. It currently parses <code>SourceFile</code>, <code>Code</code> and <code>LineNumberTable</code>, and errors on any attribute it does not recognise. On a dependency built by a newer JDK it fails with <code>unknown attribute: RuntimeTypeAnnotations</code>, having loaded every other dependency in the project. What is the defect, and what is the one change that makes the tool correct for inputs you have not seen yet?</p>
                <div class="quiz" id="quiz-jvm-attributes-2">
                    <button class="quiz-option" data-correct="true" data-explain="The defect is choosing to be closed where the format is open, and the evidence makes it unambiguous: every other dependency loaded, so the parser is not broken in general, it is incomplete. RuntimeTypeAnnotations is not exotic -- it ships in every class compiled with type annotations present, so a tool that errors on unrecognised attributes will fail on real input rather than at some theoretical boundary. The one change is to treat an unrecognised attribute name as a skip rather than an error: read attribute_length and step over that many bytes, using the name only to decide whether to parse the body. That is the whole fix, and it is a few lines. It is worth being precise about why it is correct rather than merely convenient, because the reasoning is what makes it a design decision and not a patch: the format's compatibility rule is that a reader which does not understand an attribute must ignore it, and that rule exists precisely so that a reader outlives the writers it was built for. A tool that errors instead is stricter than the format requires, which buys nothing, because the attribute it is refusing is data it was never going to interpret anyway. The general habit for any format with a length-delimited extension point is to make the unknown case the default path and the recognised case the special one, because the recognised set is the part that changes and the unknown case is the part that must not." onclick="checkQuiz('quiz-jvm-attributes-2', this)">The tool is closed where the format is open: it should skip an unrecognised attribute by its <code>attribute_length</code> rather than error. That is the format's own compatibility rule, and it is what lets a reader outlive the compilers it was built for</button>
                    <button class="quiz-option" data-correct="false" data-explain="This confuses two different things and would make the tool worse. Silently ignoring every unrecognised attribute is exactly the behaviour the format permits, but it is not the same as ignoring one whose length is wrong: a body whose length runs past the end of the file, or backwards, is malformed rather than merely unknown, and a reader that steps over it lands in the wrong place and then reads a plausible-looking attribute table from there. So the fix is not to stop checking, it is to move the check: skip an unknown name, but still validate the length against the enclosing boundary and fail if it does not fit. That distinction is what separates a reader that is future-proof from one that is merely silent, and the second kind is far more dangerous because it produces confident wrong output." onclick="checkQuiz('quiz-jvm-attributes-2', this)">The tool should silently ignore every attribute it does not recognise, since the format guarantees an unknown attribute can be skipped, and only parse the ones it needs</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: at any length-delimited extension point, make the unknown case the default path and the recognised case the special one &mdash; because the recognised set is what changes and the unknown case is what must not. Still validate the length; just do not validate the name.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The escape hatch is not unique to the class file, and the collection has the whole spectrum. <a href="/courses/wasm/lessons/wasm-objects">A WebAssembly custom section</a> is the identical mechanism at file scope: a name, a length, and contents the core specification does not define. <a href="/courses/dwarf/lessons/dwarf-versions">DWARF</a> has a versioned form of the same idea, where tag ranges are reserved per version so a new record cannot collide with an old one. <strong>The class file's contribution to the family is using a name instead of a number, which removes the need for the specification to know in advance.</strong> That is a strictly weaker guarantee bought for a strictly larger cost, and it is the right trade when the set of writers is open-ended and the set of readers is not.</p>
                <p>The contrast with the <em>instruction</em> side is the sharpest thing in this concept, and it is worth restating because it explains the format's whole shape. <strong>The instruction stream is closed and the attribute list is open.</strong> An unknown opcode makes a class unloadable; an unknown attribute makes it merely unreadable in part. That is not an accident of history &mdash; it is a deliberate asymmetry, and it is the same asymmetry as <a href="/courses/pe/lessons/pe-security-flags">a PE's optional header</a> being versioned while its sections are not, or <a href="/courses/elf/lessons/section-vs-segment">ELF's section table</a> accepting an unknown type while its <code>e_type</code> does not accept an unknown machine. <strong>Formats are open where a reader can safely step over something and closed where a reader must understand it to be correct.</strong></p>
                <p>The five attribute positions connect to <a href="/courses/jvm/lessons/jvm-code">the <code>Code</code> attribute's nesting</a>, and the rule that produced them is worth naming: <strong>an attribute lives where the thing it describes lives.</strong> A line number describes a code offset, so it goes inside the code. A source filename describes the class, so it goes on the class. A record component's type arguments describe the component, so they go on the component &mdash; which is a position that did not exist until Java 16 and was added without changing the mechanism. <strong>The container did not need extending; only the table of valid names and positions did</strong>, and that table lives in a specification rather than in the bytes.</p>
                <p>Which brings up the honest limit, and it is the reason a class file writer is harder than a class file reader. <strong>Reading the format is a few hundred lines; writing one requires implementing the bodies, honouring the position table, and computing things a reader is allowed to skip</strong> &mdash; stack maps above all, as the next-but-one concept showed. The escape hatch made the format extensible without making it easy, and the two are related more than they look: a mechanism that is trivial to skip and hard to fill is exactly a mechanism that lets old readers survive and forces new writers to work. <a href="/courses/jvm/lessons/jvm-inner-classes">Next: the <code>InnerClasses</code> attribute</a>, which is the first one where the position table and the flag table both surprise you.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-stackmaps">Previous: The Verifier's Data</a></span>
                <span><a href="/courses/jvm/lessons/jvm-inner-classes">Next: Inner Classes and Nests</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
