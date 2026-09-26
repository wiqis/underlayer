// JVM Course — Module 3: The Attribute Mechanism
// Concept: InnerClasses, NestHost, NestMembers, and why the $ in a name is not
// what it looks like.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_inner_classes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Inner Classes and Nests — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Inner Classes and Nests</h1>
            <div class="lesson-meta">22 min &middot; Module 3: The Attribute Mechanism &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Java's nested classes are not a language feature with a file format representation. They are <strong>a naming convention, two attributes, and a great deal of compiler bookkeeping</strong> &mdash; and the gap between what the source says and what the file contains is where all the difficulty is.</p>
                <p>The source says <code>static class Nested</code> and gets a file called <code>Inner$Nested.class</code>. Nothing in the source names that file. Nothing in the format requires it to be called that. And for the classes the compiler invents &mdash; anonymous ones, local ones declared inside methods &mdash; there is no name in the source <em>at all</em>, yet a file appears.</p>
                <p>So the compiler has to invent names, record what it invented, and record the relationships the language needs at run time. That is three attributes' worth of work, and each one answers a different question. <strong><code>InnerClasses</code> records what the compiler decided. <code>NestHost</code> and <code>NestMembers</code> record what the language permits.</strong> Getting that distinction straight is the difference between reading these attributes and merely decoding them.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three attributes, and the shape of each is different &mdash; which the <a href="/courses/jvm/lessons/jvm-attributes">previous concept</a> would have predicted:</p>
                <div class="formula">
InnerClasses, on a class:
    u2 number_of_classes
    then that many 8-byte records:
        u2 inner_class_info_index    the nested class, a Class entry
        u2 outer_class_info_index    the enclosing class, or 0
        u2 inner_name_index          the simple name, or 0
        u2 inner_class_access_flags  see below, and they are NOT the
                                    class flag table

NestHost, on a nested class:
    u2 host_class_index            ONE index. No count.

NestMembers, on the outermost class:
    u2 number_of_classes
    then that many u2 Class indices
</div>
                <p>And the three answer three different questions, which is the whole design:</p>
                <ul>
                    <li><strong><code>InnerClasses</code> is descriptive and duplicated.</strong> It appears on the outer class <em>and</em> on the inner one, and both copies say the same thing. It exists so a reader holding only the nested class's file can still discover the nesting, without loading the outer class.</li>
                    <li><strong><code>NestHost</code> is one index, and it is the modern replacement for the synthetic accessor problem.</strong> A nested class needs to reach its outer class's private fields. Before Java 11 the compiler generated synthetic accessor methods; from Java 11 the nest is declared instead, and <strong>every member of the nest may read every other member's private state</strong>, checked by the verifier rather than by generated methods.</li>
                    <li><strong><code>NestMembers</code> is the outer class's list of who is in the nest</strong>, and it is what lets the verifier check a private access without loading the other class. It is the index form of the same fact.</li>
                </ul>
                <p>That last distinction has a concrete consequence worth holding onto. <strong><code>InnerClasses</code> is about names; the nest is about access.</strong> They are populated independently &mdash; verified below &mdash; and a class can be in a nest without appearing in any <code>InnerClasses</code> record, and vice versa. A tool that assumes the two lists are the same will be wrong on real input.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>One source declaration, six files, and every <code>InnerClasses</code> record decoded from the raw bytes of <code>Inner.class</code>:</p>
                <div class="hex-dump">
                    <pre>  0053: 00 06
        |  +-- SIX records
        +----- SIX nested classes, 8 bytes each

  [0] inner=#7   outer=#0   name=#0   flags=0x0000
      class = Inner$1              &lt;- the ANONYMOUS Runnable
      outer = (none)                name   = (none)
  [1] inner=#18  outer=#0   name=#36  flags=0x0000
      class = Inner$1Local         &lt;- declared INSIDE A METHOD
      outer = (none)                name   = "Local"
  [2] inner=#27  outer=#13  name=#37  flags=0x4018
      class = Inner$E              enum E
      flags = ACC_FINAL ACC_ENUM 0x0008
  [3] inner=#29  outer=#13  name=#38  flags=0x0608
      class = Inner$Iface         interface Iface
      flags = ACC_INTERFACE ACC_ABSTRACT 0x0008
  [4] inner=#31  outer=#13  name=#39  flags=0x0000
      class = Inner$Member         class Member, a non-static inner class
      flags = (none)
  [5] inner=#33  outer=#13  name=#40  flags=0x0008
      class = Inner$Nested         static class Nested
      flags = 0x0008
</pre>
                </div>
                <p>Five things in that table are each a finding, and two of them contradict what a reader would guess.</p>
                <h3>The 0x0008 bit, and the third flag table</h3>
                <p>Records [2], [3] and [5] all carry <strong><code>0x0008</code></strong>, and <code>0x0008</code> is <code>ACC_STATIC</code>. A <em>class</em> cannot be static &mdash; top-level classes have no static, and <code>ACC_STATIC</code> in the class flag table means nothing at all.</p>
                <p>But these are not classes in the top-level sense. <strong><code>inner_class_access_flags</code> describes a member of a class, so it uses the field/method flag table, not the class one.</strong> And a nested enum and a nested interface are both implicitly static, which is a <em>language</em> rule: a nested interface is static because an interface cannot hold instance state, and a nested enum is static because an enum's instances are supposed to be singletons. Record [5] is the explicit case &mdash; the source said <code>static class Nested</code> and the bit records exactly that.</p>
                <div class="callout callout-warn">
                    <strong>And this is a live trap in this course's own decoder.</strong> It reported record [2] as <code>ACC_FINAL ACC_ENUM UNKNOWN(0x0008)</code> &mdash; which is exactly right and also exactly the bug the Module 2 concept warned about. The decoder used the class flag table because it was asked to render class flags, and <code>0x0008</code> is not in that table, so it honestly reported an unknown bit. <strong>The bits are identical to the member table; only the table that knows their names is different.</strong> A reader that renders <code>inner_class_access_flags</code> with the class table will show <code>UNKNOWN</code> for every nested interface and every nested enum in the file, and a reader that renders them with a merged table will show <code>ACC_STATIC</code> for a top-level class that is not static. Neither is catastrophic and both are wrong, which is the worst shape for a bug.
                </div>
                <h3>Why $1 exists and $1Local is a different thing</h3>
                <p>Record [0] is the anonymous <code>Runnable</code>, and it is the reason the file is called <code>Inner$1.class</code>. <strong>The compiler had to invent a name and recorded nothing:</strong> <code>outer_class_info_index = 0</code> and <code>inner_name_index = 0</code>. A class with no name and no recorded outer class is the file's entire justification for the <code>$1</code> convention &mdash; <strong>the number is the only identity an anonymous class has</strong>, and it is a counter of anonymous classes within the outer class, starting at 1.</p>
                <p>Record [1] is the class declared inside a method, and it is the interesting one: <strong>it has a name (<code>"Local"</code>) but no outer class recorded.</strong> The source was <code>void use() that declares class Local, then news one</code>, so <code>Local</code> is scoped to one method and the compiler emitted <code>Inner$1Local.class</code> &mdash; a <code>$1</code> <em>and</em> a name, which is not what either convention predicts on its own.</p>
                <p>The numbering scheme behind that name is worth stating because it is entirely implementation-defined and the format does not care:</p>
                <div class="hex-dump">
                    <pre>  Inner$1         the first ANONYMOUS class in Inner
  Inner$1Local    a LOCAL class: $1 because the anonymous Runnable was
                  compiled first, then the simple name
  Inner$Nested    a named nested class: just Outer$SimpleName
  Inner$E         a nested enum: Outer$SimpleName
  Inner$Iface     a nested interface: Outer$SimpleName
  Inner$Member    a non-static inner class: Outer$SimpleName

  the rule javac actually uses: an ANONYMOUS class gets Outer$N where N
  counts anonymous classes; a LOCAL class gets Outer$NLocal where N is
  the counter at the time it was compiled; a NAMED nested class gets
  Outer$SimpleName. All three are conventions, not rules -- nothing in
  the format requires any of them, and every JVM accepts any name.
</pre>
                </div>
                <p><strong>Which brings up the question the descriptor grammar only hinted at: the <code>$</code> in <code>LDesc$Nested;</code> is not a nesting marker.</strong> It is a legal character in a Utf8 entry, the compiler happens to use it to join an outer and inner name, and a class genuinely named <code>A$B</code> in Java is indistinguishable in the file from a nested class <code>B</code> of <code>A</code>. The method reference in Module 1 makes it concrete &mdash; <code>this::id</code> compiles to a synthetic method named <code>lambda$new$0</code>, a <code>$</code> in the middle of a method name that has nothing to do with nesting. <strong>The attribute is the only place the relationship is recorded, which is exactly why it exists.</strong></p>
                <h3>The nest, and that it is a different set</h3>
                <p>Now the other two attributes, from the same file, and this is where the sets diverge:</p>
                <div class="hex-dump">
                    <pre>  NestMembers on Inner.class -- 6 entries:
      #27 Inner$E        #29 Inner$Iface     #31 Inner$Member
      #33 Inner$Nested   #18 Inner$1Local    #7  Inner$1

  NestHost on Inner$Nested.class -- ONE u2, no count:
      0010    ->  #16 = Inner
</pre>
                </div>
                <p><code>NestMembers</code> lists all six, which is exactly the <code>InnerClasses</code> set. So for this class the two agree &mdash; <strong>and that is a coincidence of a small example, not a rule.</strong> The distinction is what each one is for: <code>InnerClasses</code> says how the compiler named things, <code>NestMembers</code> says who may read whose private fields. A class can be in a nest without being a nested class in the source sense, and the format has no requirement that the lists match.</p>
                <p>And note the shape difference once more, because it is the previous concept's point made concrete: <strong><code>NestHost</code> is a bare index with no count, while <code>NestMembers</code> is a counted list.</strong> A reader that assumed a common body shape would read <code>NestHost</code>'s index as a count and walk into the following attribute. The raw bytes <code>00 10</code> are two bytes of body; there is no count anywhere in them.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a nest actually buys, and why it replaced synthetic accessors. The source-level problem is old and the mechanism is not obvious:</p>
                <div class="formula">
  BEFORE Java 11: a nested class reading its outer class's private field

    class Outer has a private int secret = 42, and a nested
    class Inner whose method read() returns that field.

    secret is private to Outer. Inner is a DIFFERENT class. So javac
    generated, in Outer.class:

      static synthetic int access$000(Outer)     &lt;- a bridge
      static synthetic int access$100(Outer)     &lt;- and Inner gets its own

    and Inner.read() compiles to:
      aload_0
      invokestatic  Outer.access$000:(LOuter;)I

    the METHOD CALL costs real bytes, shows up in profiles, and the
    bridge is visible in the class file even though nobody wrote it.


  FROM Java 11: the nest

    Outer$Nested.class gets:  NestHost -> Outer
    Outer.class gets:         NestMembers -> Outer$Nested

    and Inner.read() compiles to:
      aload_0
      getfield      Outer.secret

    a DIRECT field access. No bridge, no call, and the verifier checks
    the nest membership instead.
</div>
                <p><strong>That is a real optimisation with a real mechanism behind it</strong>, and the interesting part is what moved. The compiler no longer has to invent a method; the <em>verifier</em> now does the work, by consulting <code>NestHost</code> and <code>NestMembers</code> when it type-checks the <code>getfield</code>. The cost has not disappeared &mdash; it has moved from the class file's method table to its attribute list, and from run time to load time. That is the trade the format prefers throughout: <strong>pay at load, once, so the hot path stays direct.</strong></p>
                <p>And the two attributes are what make that possible from both sides. A <code>getfield</code> inside <code>Inner</code> needs to know that <code>Inner</code> belongs to <code>Outer</code>'s nest &mdash; so <code>Inner$Nested.class</code> needs <code>NestHost</code>. And the verifier needs to know that <code>Outer</code> claims <code>Inner</code> as a member, rather than trusting a self-declaration &mdash; so <code>Outer.class</code> needs <code>NestMembers</code>. <strong>Both directions are required because either one alone would let a class claim access it has not been given.</strong></p>
                <p>That is the security argument, and it is worth making explicit because it is the same argument as <a href="/courses/pe/lessons/pe-load-config">control flow guard</a> and <a href="/courses/coff/lessons/coff-weak-externals">weak externals</a> in this collection: <strong>a claim about a relationship has to be checkable by someone who is not the claimant.</strong> <code>NestMembers</code> is the outer's side of that, and without it <code>NestHost</code> would be a class simply asserting that it may read private state. Compare a <a href="/courses/elf/lessons/visibility">ELF symbol's binding and visibility</a>, which is the same two-sided arrangement between a symbol and the section that defines it.</p>
                <p>One consequence worth knowing before you read a real file: <strong>the nest is not the same as the enclosing class, and it is not transitive.</strong> A class in <code>Outer</code>'s nest can read <code>Inner</code>'s privates and vice versa, but a third class in the same nest that is a nested class of a <em>different</em> member is not automatically related. And a <code>static</code> nested class is in the nest like any other, because a static nested class still has access to the outer's privates in the source language. The <code>Inner$E</code> enum in this course's sample is nested, static, and a member of the nest &mdash; three facts from three different mechanisms, and only the third one is about access.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Inner.class
$ python3 courses/jvm/assets/samples/crosscheck.py classes/Inner.class</code></pre>
                <ul>
                    <li><strong>Decode <code>Inner.class</code>'s six <code>InnerClasses</code> records by hand.</strong> Count is <code>00 06</code> and each record is eight bytes. <strong>Then explain each of the three zero fields</strong> &mdash; which records have <code>outer = 0</code>, which have <code>name = 0</code>, and why the anonymous class has both.</li>
                    <li><strong>Prove the two flag tables differ.</strong> Take the nested interface's <code>0x0608</code> and render it with the class table and with the member table. <strong>The class table calls <code>0x0008</code> unknown; the member table calls it <code>ACC_STATIC</code></strong>, and the interface genuinely is static. That is the Module 2 finding arriving as a live bug in a real file.</li>
                    <li><strong>Find the <code>$1</code> counter.</strong> Add a second anonymous class to <code>Inner</code> and recompile. <strong>The new file will be <code>Inner$2.class</code></strong>, and the local class declared after it will move to <code>Inner$2Local</code> &mdash; which shows the counter is shared, and is the most surprising naming fact in the format.</li>
                    <li><strong>Compare the three sets.</strong> Dump <code>InnerClasses</code> from <code>Inner.class</code>, <code>NestMembers</code> from <code>Inner.class</code>, and <code>NestHost</code> from each nested class. <strong>Then deliberately break the correspondence</strong> &mdash; delete a <code>NestMembers</code> entry &mdash; and confirm the JVM rejects the class even though the <code>InnerClasses</code> records are untouched.</li>
                    <li><strong>Count the synthetic accessors before and after.</strong> Compile with <code>--release 8</code> and with <code>--release 17</code>, and count the <code>access$</code> methods. <strong>They disappear in the newer one, replaced by two attributes and a <code>getfield</code></strong> &mdash; and the file gets smaller even though it gained an attribute.</li>
                    <li><strong>Break the <code>NestHost</code> shape deliberately.</strong> Write a reader that assumes every attribute body is a counted list, and run it on a nested class. <strong>It will read the <code>NestHost</code> index as a count</strong> and walk into the following attribute, and the end-of-file assertion will be the only thing that catches it.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a <code>InnerClasses</code> record has <code>inner = #7</code>, <code>outer = 0</code>, <code>name = 0</code>, <code>flags = 0</code>. What class is this, why does its file have a numeric component in its name, and what does the <code>0x0008</code> bit mean on a record whose other flags are <code>0x4018</code>?</p>
                <div class="quiz" id="quiz-jvm-inner-classes-1">
                    <button class="quiz-option" data-correct="true" data-explain="All three parts follow from the two fields being zero. An inner_class_info_index with an outer of zero and a name of zero is a class the compiler invented and declined to describe: that is an anonymous class, and the only identity it has is the number in its file name, which is why the file is called Outer$1 rather than anything derived from the source. The counter starts at 1 because it counts anonymous classes within the outer class, and a local class declared later shares the counter, which is why a file can be named Outer$1Local. The 0x0008 is the more interesting half. It is ACC_STATIC, which is meaningless for a top-level class, but inner_class_access_flags describes a member of a class and therefore uses the field and method flag table rather than the class one. So 0x4018 is ACC_FINAL, ACC_ENUM and ACC_STATIC together, describing a nested enum, and the static bit is real: a nested enum is implicitly static because its instances are meant to be singletons. The general trap is that the bits are the same bits; only the table that names them differs, so a reader using the wrong table reports an unknown bit on every nested interface and every nested enum in the file, and a reader using a merged table reports static on top-level classes that are not." onclick="checkQuiz('quiz-jvm-inner-classes-1', this)">An anonymous class &mdash; the compiler invented the name and recorded neither an outer class nor a simple name, so the <code>$1</code> counter is its only identity. And <code>0x0008</code> is <code>ACC_STATIC</code>, which is real here because <code>inner_class_access_flags</code> uses the member flag table, not the class one &mdash; so those flags mean a nested final enum</button>
                    <button class="quiz-option" data-correct="false" data-explain="The identification is right and the flag reading is wrong in the most instructive way, because it is the mistake this course made and had to correct. 0x0008 is not undefined in this position; it is ACC_STATIC, and it is defined precisely because inner_class_access_flags describes a member rather than a top-level class. A nested enum is implicitly static in the source language, so the bit is carrying real information, and a reader that reports it as unknown is using the wrong flag table rather than finding an undefined bit. The 0x4000 alongside it is ACC_ENUM, which is also a class-table bit but happens to be meaningful on both a class and a field, which is exactly why the error is easy to miss: most of the flags decode correctly and only one does not." onclick="checkQuiz('quiz-jvm-inner-classes-1', this)">An anonymous class, and the <code>0x0008</code> bit is undefined in this position because a class cannot be static &mdash; it is padding, since <code>inner_class_access_flags</code> reuses the class flag table where that bit has no meaning</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a tool that finds every class in a nest, given one class file. It reads <code>InnerClasses</code> from that file and follows each record's <code>outer_class_info_index</code>, which works for a static nested class and fails for both an anonymous class and a class declared inside a method: in both cases the outer index is zero, so the tool finds nothing and reports the class as having no nest. <code>javap</code> on the same file lists the nest correctly. What is the defect, what is the correct source for the relationship, and what is the general rule about trusting a field that is allowed to be zero?</p>
                <div class="quiz" id="quiz-jvm-inner-classes-2">
                    <button class="quiz-option" data-correct="true" data-explain="The defect is choosing the wrong attribute for the job, and the two failures are diagnostic rather than accidental. InnerClasses is the compiler's record of what it named things, and it is allowed to have a zero outer index because a class genuinely need not have a recorded enclosing class: an anonymous one has no name to record, and a method-local one is scoped somewhere a single enclosing class does not describe. NestHost and NestMembers are the language's record of who may read whose private fields, and they are populated independently of the naming. So the correct source for the tool's question is NestHost on the class itself, or NestMembers on the candidate host, and a tool that switches attributes fixes the bug and gains a class it could not previously see at all, because the anonymous class has an InnerClasses record with no outer and no name and is otherwise unreachable by this route. The general rule about zero-valued fields is worth stating because it recurs across this format: a field that is permitted to be zero is not a field that carries information in the zero case, and a consumer that treats a zero as a value rather than as an absence will invent a relationship that does not exist. Constant pool index zero, the reserved first entry, NestHost's absent case, and the exception table's any-type are all the same pattern, and the correct handling in each case is to stop rather than to guess." onclick="checkQuiz('quiz-jvm-inner-classes-2', this)">It is using <code>InnerClasses</code>, which records naming rather than access, and its outer index is legitimately zero for exactly the two kinds of class that have no single enclosing class. Use <code>NestHost</code> on the class or <code>NestMembers</code> on the host. A zero-valued field that is permitted to be zero carries no information in that case, and a consumer must treat it as an absence rather than a value</button>
                    <button class="quiz-option" data-correct="false" data-explain="This would fix the two observed failures without addressing the cause, and it would fail on the next kind of input. Walking outward by file name is a heuristic that happens to work for the shapes this sample happens to contain, and the class files involved are not even on disk under those names necessarily: a class can be renamed or repackaged by a build step, and a jar tool can rewrite the entries while leaving the class file's own contents untouched. More decisively, it cannot recover the anonymous class at all, because there is nothing in any file to follow outward from it: its InnerClasses record has a zero outer and a zero name, so the only handle on it is the NestMembers list of its host, which is a direction this approach never traverses. Reading the attributes is both correct and available; inferring from names is neither." onclick="checkQuiz('quiz-jvm-inner-classes-2', this)">The tool should fall back to the file path, deriving the outer class from the <code>$</code> in <code>Inner$1Local.class</code> when the attribute's outer index is zero, since javac's naming convention is reliable in practice</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a field that is permitted to hold a sentinel value carries no information when it does, and a consumer that reads a sentinel as a value will invent a relationship that is not there. Check for the sentinel before you use the field.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>A nest is a two-sided declaration, and this collection has three other mechanisms built the same way, for the same reason. <a href="/courses/elf/lessons/visibility">An ELF symbol's binding and an object's visibility</a> are recorded by the producer and checked by whoever consumes the reference. <a href="/courses/pe/lessons/pe-load-config">A PE's load config</a> records guard metadata that the loader verifies. <a href="/courses/coff/lessons/coff-weak-externals">A COFF weak external</a> is a claim about a symbol that the linker is expected to check rather than trust. <strong>The pattern is always the same: a claim about a relationship is only useful if something other than the claimant checks it, and a one-sided declaration is just an assertion.</strong></p>
                <p>The <code>$</code> finding is a naming lesson the whole collection keeps teaching. <a href="/courses/pe/lessons/pe-imports">A PE import is by ordinal, a COFF static-library symbol by ordinal in a string table</a>, and both are positions that a producer fills in and a consumer resolves. The Java <code>$</code> convention is the weakest version of the family &mdash; a name, not a position, and one the format does not require &mdash; which is why it is the one that needs an attribute to record the real relationship. <strong>Compare the <a href="/courses/elf/lessons/symbol-table">ELF symbol table</a>, where the name is in the file and the index is assigned by the linker</strong>: a position is resolved, a name is trusted, and only the second kind needs a second attribute to say what it means.</p>
                <p>The synthetic-accessor story connects to <a href="/courses/coff/lessons/coff-comdat-linking">COMDAT</a> and to <a href="/courses/coff/lessons/coff-weak-externals">weak externals</a> in a specific way: all three are compiler-generated members that exist only to satisfy a language rule the machine does not have. A nested class reading a private field is not a privilege the CPU understands; <code>private</code> is enforced by the compiler and the verifier, so the mechanism has to be a generated method or a declared relationship. <strong>The trend across all three is the same &mdash; move enforcement from generated code to checked metadata</strong>, and the direction of travel is set by the cost of generated code, which is bytes in the file and a call in the profile.</p>
                <p>And the flag-table surprise is the third time this course has found it, which is the argument for teaching it as a general habit rather than a fact. A <a href="/courses/elf/lessons/elf-identification">section header's flags</a> and the file header's are different; a <a href="/courses/pe/lessons/pe-section-table">PE section's characteristics</a> are a third vocabulary. <strong>Any format with more than one kind of record ends up with more than one flag table, because the flags describe the record and the records differ</strong> &mdash; and the failure is always a bit reported with a name that is meaningless in that position, which is a class of wrong that no reader can detect from the value alone.</p>
                <p>Next: <a href="/courses/jvm/lessons/jvm-signatures">the <code>Signature</code> attribute</a>, which is the second type grammar in the format &mdash; and the one place where the file says something the language deliberately erased.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-attributes">Previous: The Escape Hatch</a></span>
                <span><a href="/courses/jvm/lessons/jvm-signatures">Next: The Signature Attribute</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
