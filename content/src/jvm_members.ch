// JVM Course — Module 2: Members and Code
// Concept: fields, methods, the descriptor grammar, three separate access-flag
// tables, and the local slots a long parameter quietly costs two of.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_members() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Fields, Methods and Descriptors — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Fields, Methods and Descriptors</h1>
            <div class="lesson-meta">22 min &middot; Module 2: Members and Code &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything after the constant pool describes what a class <em>has</em> and what it can <em>do</em>. Both are the same shape &mdash; a flag word, a name index, a descriptor index, and a list of attributes &mdash; and the descriptor is where the interesting grammar lives.</p>
                <p>A descriptor is how the class file spells a type. Not a name, not a reference to the <a href="/courses/jvm/lessons/jvm-constant-pool">constant pool</a>'s idea of a class, but <strong>a complete, self-contained type written out in characters</strong>. The whole JVM type system fits in about a dozen symbols, and reading them is a skill in its own right &mdash; there is nothing else in the format where so much meaning is packed into so few bytes.</p>
                <p>It is also where the format stops being a name table and starts describing behaviour, because a method's descriptor says what goes in and what comes out. That is enough for the verifier to type-check a call, to decide whether an override is legal, and to reject a class that claims to implement an interface it does not. <strong>All of that from one line of printable ASCII.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The complete type grammar, as verified against three independent readers on a class declaring one field of every kind:</p>
                <div class="hex-dump">
                    <pre>  PRIMITIVES          one character each

    Z   boolean          B   byte             C   char
    S   short            I   int              J   long
    F   float            D   double
                        V   void  -- ONLY as a method's return

  REFERENCES          L, an internal name, and a semicolon

    Ljava/lang/String;            a class or interface
    LDesc$Nested;                 a nested class, $ separating the parts

  ARRAYS              one [ per dimension, then the element type

    [I                  int[]
    [[I                 int[][]
    [Ljava/lang/String;    String[]
    [[D                 double[][]

  METHODS             an open paren, the parameters, a close paren, the return

    ()V                no parameters, returns void
    (I)Z               one int, returns boolean
    (IJLjava/lang/String;[ILjava/lang/Object;)V
                        int, long, String, int[], Object; returns void
</pre>
                </div>
                <p>Five things in that grammar are worth stating outright, because each one is a decision rather than a notation.</p>
                <ul>
                    <li><strong>Eight primitives, no pointers, and no <code>unsigned</code>.</strong> There is no way to spell &ldquo;a pointer&rdquo; because there are no pointers &mdash; every object is a reference the runtime manages. And there is no unsigned integer, which is a deliberate language decision that reaches all the way down into the file's type system. Compare <a href="/courses/wasm/lessons/wasm-types">WebAssembly's four numeric types</a>, which made the same cut from a different direction.</li>
                    <li><strong><code>void</code> is a return type only.</strong> <code>V</code> can never appear as a parameter, and a constructor's descriptor is <code>()V</code> because it returns nothing and declares no parameters regardless of the source. <strong>A return type of <code>V</code> and a parameter list of zero are two different things that happen to be spelled the same way</strong> &mdash; which is why a descriptor parser needs to know which position it is in.</li>
                    <li><strong>Arrays are prefix notation.</strong> The <code>[</code> comes before the element type, so <code>int[][]</code> is <code>[[I</code> and not <code>[I[</code>. That is the reverse of C, and the reason is that the descriptor is read left to right into a type with no lookahead: <code>[</code> is a complete type on its own once you have read what follows it.</li>
                    <li><strong>Internal names use <code>/</code> and <code>$</code>.</strong> A class is <code>Ljava/lang/String;</code> &mdash; slashes, not dots &mdash; and a nested class is <code>LDesc$Nested;</code>, with a dollar sign. <strong>The <code>$</code> is compiler-generated and not always a nesting</strong>, which is the next concept's problem; for now it is a character to expect.</li>
                    <li><strong>There is no generics syntax in a descriptor.</strong> A field declared <code>List&lt;String&gt;</code> has the descriptor <code>Ljava/util/List;</code> &mdash; the type arguments are not there. They live in a separate <code>Signature</code> attribute, and their absence from the descriptor is precisely what makes the descriptor usable by the verifier: the erased type is all the verifier needs.</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>What a class with one field of every type and a handful of methods actually stores. The descriptor column is the entire per-member cost after the name, and it is worth seeing how small it is:</p>
                <div class="hex-dump">
                    <pre>  field     descriptor
  z         Z
  b         B
  c         C
  s         S
  i         I
  j         J
  f         F
  d         D
  ref       Ljava/lang/String;
  arr       [I
  jag       [[I
  sarr      [Ljava/lang/String;

  method     descriptor
  m          ()V
  ret        ()I
  args       (IJLjava/lang/String;[ILjava/lang/Object;)V
  manyRet    ()J
  usesNested (LDesc$Nested;)LDesc;
</pre>
                </div>
                <p>All of those strings came out of the file and all three readers agree on every one of them, name by name and descriptor by descriptor. <strong>The longest is 41 characters for five parameters</strong>, and the shortest is 3. A field of type <code>boolean</code> costs one byte of type information. There is no per-type overhead anywhere.</p>
                <h3>Three access-flag tables, not one</h3>
                <p>The <code>access_flags</code> field is a <code>u2</code> in all three places it appears &mdash; on the class, on each field, on each method &mdash; and <strong>the three tables are different</strong>. That is not a design convenience; it is a genuine trap, and this course's own decoder shipped with a bug in exactly this area.</p>
                <div class="hex-dump">
                    <pre>  CLASS                         bit 0x0001 ACC_PUBLIC
                                  bit 0x0010 ACC_FINAL
                                  bit 0x0020 ACC_SUPER
                                  bit 0x0200 ACC_INTERFACE
                                  bit 0x0400 ACC_ABSTRACT
                                  bit 0x1000 ACC_SYNTHETIC
                                  bit 0x2000 ACC_ANNOTATION
                                  bit 0x4000 ACC_ENUM
                                  bit 0x8000 ACC_MODULE

  FIELD                         bit 0x0001 ACC_PUBLIC
                                  bit 0x0002 ACC_PRIVATE
                                  bit 0x0004 ACC_PROTECTED
                                  bit 0x0008 ACC_STATIC
                                  bit 0x0010 ACC_FINAL
                                  bit 0x0040 ACC_VOLATILE
                                  bit 0x0080 ACC_TRANSIENT
                                  bit 0x1000 ACC_SYNTHETIC
                                  bit 0x4000 ACC_ENUM

  METHOD                        bit 0x0001 ACC_PUBLIC
                                  bit 0x0002 ACC_PRIVATE
                                  bit 0x0004 ACC_PROTECTED
                                  bit 0x0008 ACC_STATIC
                                  bit 0x0010 ACC_FINAL
                                  bit 0x0020 ACC_SYNCHRONIZED
                                  bit 0x0040 ACC_BRIDGE
                                  bit 0x0080 ACC_VARARGS
                                  bit 0x0100 ACC_NATIVE
                                  bit 0x0400 ACC_ABSTRACT
                                  bit 0x0800 ACC_STRICT
                                  bit 0x1000 ACC_SYNTHETIC
</pre>
                </div>
                <p>Look at what overlaps and what does not. <code>0x0010</code> is <code>ACC_FINAL</code> everywhere &mdash; consistent. <code>0x1000</code> is <code>ACC_SYNTHETIC</code> everywhere. But <code>0x0008</code> is <code>ACC_STATIC</code> on a field and a method and <em>means nothing at all</em> on a class, while <code>0x0002</code> is <code>ACC_PRIVATE</code> on a field and a method and is not defined for a class. <strong>A reader that uses one table for all three will report names that are not wrong so much as meaningless</strong>, and the error is invisible because the bits it misinterprets are usually clear.</p>
                <div class="callout callout-warn">
                    <strong>A real one, from this course's own decoder.</strong> The flag tables shipped here had <code>0x0009</code> listed as a single entry called <code>ACC_FINAL</code>. That was wrong twice over: <code>0x0009</code> is not a bit at all but the <em>combination</em> <code>ACC_PUBLIC | ACC_STATIC</code>, and <code>ACC_FINAL</code> is <code>0x0010</code>. Every <code>public static</code> method was therefore reported as <code>ACC_PUBLIC ACC_FINAL</code> &mdash; two wrong names and one missing. It was caught by running the decoder and <code>javap</code> side by side on the same file and comparing, which is the only kind of check that works: <strong>all three readers could have shared the mistake</strong>, because a table copied from a wrong source is wrong identically everywhere. The general rule is that a table of names is the one part of a decoder that cannot be validated by agreement, and has to be checked against something outside the set of readers.
                </div>
                <h3>ConstantValue: a field's initial value, stored in the pool</h3>
                <p>One attribute deserves separate mention because it is the only place the file stores a value rather than code. A <code>static final</code> field of a primitive or <code>String</code> type gets a <code>ConstantValue</code> attribute whose entire body is a two-byte pool index:</p>
                <div class="hex-dump">
                    <pre>  ConstantValue:
    u2 constantvalue_index      a pool index, and that is the whole attribute

  and the pool entry it points at is the value itself:
    #20 = Integer            2135567385
    #23 = Long               81985529216486895l
    #27 = Float              3.5f
    #30 = Double             -2.718281828459045d
    #34 = String             #35
    #35 = Utf8               hello
</pre>
                </div>
                <p><strong>No bytes of the value appear in the attribute at all</strong> &mdash; it is a pointer into the pool like everything else. And note what that buys: the value is shared with every other occurrence of it in the file. Two classes with the same constant do not each store it; they each store an index, and the compiler emits one pool entry. <strong>That is the constant pool doing its job one more time, and it is the reason the format needs no separate data section.</strong></p>
                <p>The restriction to primitives and <code>String</code> is a language rule rather than a format one, and it is worth knowing why: a compile-time constant must have a value the compiler can write down and the verifier can check. An arbitrary object does not have one, which is why <code>static final List&lt;String&gt; EMPTY = ...</code> is legal Java and gets a <code>&lt;clinit&gt;</code> method that builds it at class-initialisation time instead.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The other two-slot rule. The <a href="/courses/jvm/lessons/jvm-constant-pool">constant pool</a> gives <code>Long</code> and <code>Double</code> two indices each; <strong>the local variable frame does the same thing to the same two types</strong>, and for a related reason. Here is every method of a ten-method class, with the slot arithmetic checked against the file:</p>
                <div class="hex-dump">
                    <pre>  method  descriptor      this  slots   predicted  max_locals
  a       ()V              yes      0          1           1
  b       (I)V             yes      1          2           2
  c       (II)V            yes      2          3           3
  d       (J)V             yes      2          3           3   &lt;-- long is TWO
  e       (JJ)V            yes      4          5           5
  f       (D)V             yes      2          3           3   &lt;-- double is TWO
  g       (IJD)V           yes      5          6           6
  s       (IJD)V           no       5          5           5   &lt;-- static: no this
  h       (Ljava/lang/String;[ILjava/lang/Object;)V
                          yes      3          4           4   &lt;-- arrays are ONE
</pre>
                </div>
                <p>Ten methods, ten predictions, ten matches. Three rules produce all of it:</p>
                <div class="formula">
max_locals = (1 if the method is NOT static, else 0)
           + sum over each declared parameter of:
                 2   if the type is long or double
                 1   otherwise, INCLUDING every array and every reference

so:
  d(J)V            1 + 2             = 3
  g(IJD)V          1 + 1 + 2 + 2     = 6
  s(IJD)V          0 + 1 + 2 + 2     = 5   (static)
  h(String[], ...)  1 + 1 + 1 + 1     = 4   (three references)
</div>
                <p><strong>Why 64-bit types take two slots is a register-allocation decision, and it explains the descriptor rule too.</strong> The JVM's calling convention passes 32-bit values in one slot and 64-bit values in two, so that a <code>long</code> and two <code>ints</code> both occupy eight bytes and a <code>max_locals</code> can be reasoned about as a frame size. <code>J</code> and <code>D</code> are the only two descriptor characters with this property, and a parser needs to know that before it can walk a parameter list &mdash; because <code>(IJ)</code> has three slots, not two, and a tool that assumes one-slot-per-parameter computes a frame size a quarter too small.</p>
                <p>And the array case is the one that catches people, including a verification script written for this course: <strong><code>[I</code> is one slot, not two.</strong> The <code>[</code> is part of the type, not a separate thing, and an array of any dimension is a single reference. Getting it wrong inflates the count and makes <code>max_locals</code> look too large, which is a confusing symptom because the real rule is right and only the arithmetic is wrong.</p>
                <div class="callout callout-warn">
                    <strong>And note what <code>max_locals</code> is not.</strong> It is not the number of local variables, and it is not the number the method might use. It is the number of slots the frame needs for the <em>parameters and <code>this</code></em>, and it is set from the signature before the body is looked at. A method that declares a hundred locals and uses none of them still has <code>max_locals</code> equal to its parameter count plus one. <strong>The body's own locals live above that mark and are the verifier's business, not the signature's</strong> &mdash; which is why adding an unused local to a method does not change the descriptor, and why a tool that rebuilds a frame from the descriptor alone gets the right answer for the parameters and no information about the rest.
                </div>
                <p>One more consequence worth flagging for the next concept, because it is where a reader can lose its place: <strong>descriptor parsing is recursive and self-delimiting, and the only field that is not one byte per character is the name inside an <code>L...;</code>.</strong> <code>LDesc$Nested;</code> is a reference whose name is <code>Desc$Nested</code>, terminated by the first <code>;</code> &mdash; and the name may contain almost anything except that one character. So a descriptor parser cannot be a fixed-length reader; it must scan to the terminator, which is the same walk-to-a-terminator discipline the WebAssembly and PE courses arrived at independently.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Desc.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Desc.class</code></pre>
                <ul>
                    <li><strong>Write a descriptor parser and test it on all twelve shapes.</strong> The eight primitives, three array forms, and two method forms from the table above. <strong>Then add the case that breaks a naive parser: a class whose internal name contains a <code>$</code> and a digit</strong>, which is what a nested or anonymous class gives you.</li>
                    <li><strong>Predict <code>max_locals</code> before you look.</strong> Take ten method signatures, compute the slots from the rules, then check against the file. <strong>The one you will get wrong is the first <code>long</code> or <code>double</code> parameter</strong>, and finding out that you got it wrong by looking is worth more than being told.</li>
                    <li><strong>Find the array trap deliberately.</strong> Write a slot counter that treats <code>[</code> as a separate token and watch <code>max_locals</code> come out too large for any method with an array parameter. <strong>Producing a wrong prediction on purpose and seeing exactly how it is wrong is the fastest way to internalise a rule.</strong></li>
                    <li><strong>Build a class using every access flag you can reach and diff the three readers.</strong> <code>public abstract class</code> with <code>volatile transient</code> fields and a <code>native synchronized</code> method. <strong>Run all three and compare flag by flag</strong> &mdash; and remember that agreement is not proof, because a wrong table copied three times agrees perfectly.</li>
                    <li><strong>Show that a constant is stored once.</strong> Two classes each with <code>static final int X = 42</code>, and one class with it twice. Compare the pool sizes. <strong>The pool is a dictionary, and this is the clearest demonstration of what that buys</strong> &mdash; the same number appears once however many fields want it.</li>
                    <li><strong>Read a <code>ConstantValue</code> and follow the index.</strong> Find the attribute, note the two-byte body, resolve the pool index, and confirm the value. <strong>Then change one byte of the value and watch the class still load</strong> &mdash; which tells you something important about how little a class file promises about its own constants.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a non-static method has the descriptor <code>(IJ[D)Ljava/lang/String;</code>. How many local slots does its frame need for parameters and <code>this</code>, and what is the descriptor of the parameter that is a <code>double</code> array?</p>
                <div class="quiz" id="quiz-jvm-members-1">
                    <button class="quiz-option" data-correct="true" data-explain="Four rules combine and three of them are the kind that surprise people. This is an instance method, so `this` takes slot 0 and everything else starts at 1. The int takes one slot, giving 2. The long takes two, giving 4. The double array takes exactly one, because an array is a single reference regardless of its dimensions, giving 5. And the return type contributes nothing to the frame, because a return value lives on the stack rather than in a local. The descriptor of that array parameter is spelled with one bracket for one dimension, so a double array is [D and a double array of arrays is [[D. The two-slot rule for long and double is the same rule the constant pool applies to the same two types, and it exists for the same underlying reason: 64-bit values get two 32-bit slots' worth of room so that a frame can be sized by adding. Note also that the return type being a reference costs nothing in the frame at all, which is worth internalising because a descriptor can be a long string while the frame is six bytes." onclick="checkQuiz('quiz-jvm-members-1', this)">Five slots: <code>this</code> is 1, the <code>int</code> is 1, the <code>long</code> is 2, the array is 1, and the return value adds nothing. The parameter's descriptor is <code>[D</code> &mdash; one bracket for one dimension, and an array of arrays would be <code>[[D</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="The count is right and one of the reasons is wrong, which is a useful shape for this kind of error. The array is indeed one slot and the return type does indeed add nothing, but the long's two slots are not a frame-alignment rule about the method as a whole. They are a per-value property of the 64-bit types specifically, applied independently at every occurrence. A method with three long parameters needs six slots for them plus one for this, with nothing padded, because each long is two slots rather than one. And a long does not align the frame to an even boundary at the start; a method whose first parameter is a long puts it in slots 1 and 2, not 2 and 3." onclick="checkQuiz('quiz-jvm-members-1', this)">Six slots, because the frame must be aligned to eight bytes for the 64-bit values, so the three parameters plus this take six with one byte of padding. The array parameter's descriptor is <code>D[]</code></button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a bytecode tool that computes a method's stack frame size for a JNI-style native call. It works on every method except those taking a <code>long</code> or a <code>double</code>, where it hands the native code a frame two slots too small and the process corrupts memory. Everything else in your pipeline is correct, and the affected methods all pass <code>javap -v</code> cleanly. What is the defect, what is the one-line check against the file, and why is it likely that this bug survived testing on a codebase with hundreds of methods?</p>
                <div class="quiz" id="quiz-jvm-members-2">
                    <button class="quiz-option" data-correct="true" data-explain="The defect is a one-slot-per-parameter assumption, and the one-line check is to take any affected method's max_locals from the file and subtract the count for this alone: the remainder must equal the sum of per-parameter slot counts, with long and double counted as two. That is a subtraction you can do on a single method and it either balances or does not, so the diagnosis is immediate. The survival question is the more interesting half, and the answer is that the bug is invisible precisely where it does not fire. A method with no 64-bit parameter computes the right answer for the wrong reason, so it cannot distinguish a correct implementation from an accidentally correct one. A test suite that checks output values on a hundred methods with mostly int and reference parameters will pass entirely, because there is no observation that distinguishes the two implementations. This is the mirror image of the two-slot constant pool rule, and it produces the same blind spot: both bugs are invisible until one specific input type appears. The general habit is that an implementation which is accidentally correct on your test data has not been tested, and the only reliable way to find those cases is to enumerate the input space and ask which cases your data happens not to cover. Here that enumeration is eight primitive types, and long and double are two of them." onclick="checkQuiz('quiz-jvm-members-2', this)">The tool counts one slot per parameter and ignores that <code>long</code> and <code>double</code> take two. Subtract the count for <code>this</code> from the file's <code>max_locals</code> and the remainder will not balance. It survived because every method without a 64-bit parameter computes the right answer for the wrong reason, so nothing in the test data could distinguish the two implementations</button>
                    <button class="quiz-option" data-correct="false" data-explain="The evidence points at the per-value slot count and away from anything about parameter order or descriptor parsing. If the parser were misreading descriptors, every method would be affected rather than only those with 64-bit parameters, because every method has a descriptor. If it were an ordering bug, the failures would not correlate so cleanly with a single type, since reordering by one slot would break int-only methods too. The correlation with long and double specifically is the whole diagnosis: it names the one rule in this concept that is not one-slot-per-value, and there is exactly one such rule." onclick="checkQuiz('quiz-jvm-members-2', this)">The descriptor parser is mis-parsing <code>J</code> and <code>D</code> as reference types, so it looks up a name in the constant pool for a primitive and gets a pool index back where a slot count was expected</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a bug correlates perfectly with one input type, that type is where the rule you are missing lives. And when a tool is accidentally correct on your test data, enumerate the input space and ask which cases your data happens not to contain.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>A descriptor is a type written as a string, and this collection has three other places that does the same thing for the same reasons. <a href="/courses/coff/lessons/coff-file-header">A COFF or PE symbol has no type at all</a> &mdash; only a storage class &mdash; so a linker can check that a symbol exists but not that it is callable. <a href="/courses/dwarf/lessons/dwarf-types">A DWARF type is a graph of DIEs</a> joined by <code>DW_AT_type</code>, so a type is a pointer chase rather than a string. <a href="/courses/wasm/lessons/wasm-types">A WebAssembly value type is one byte</a>, with function types in a separate section entirely. <strong>The class file descriptor is the only one of the four that puts a complete type in a single self-delimiting string, and that is why it is the only one the verifier can read without a second lookup.</strong></p>
                <p>The three-flag-tables decision is the sharpest contrast, because it is a case of a format doing the conventional thing and paying for it. <a href="/courses/elf/lessons/elf-identification">An ELF header has one flags word</a> and a section header has another, and the two are documented separately for the same reason. <a href="/courses/pe/lessons/pe-section-table">A PE section's characteristics word</a> is a third table again. <strong>Every format with more than one kind of record ends up with more than one flag vocabulary</strong>, and the reason is structural: the flags describe the thing, and the things are different. Consolidating them would mean either meaningless bits or an indirection, and both are worse than a second table.</p>
                <p>The two-slot rule for 64-bit values is the concept's real finding and it connects to something in the previous one on purpose. <strong>A <code>long</code> takes two pool indices and two local slots, for the same underlying reason in both places</strong>: 64-bit values are handled as two 32-bit units so that a size can be computed by addition rather than by a special case. The constant pool does it so an entry fetch is uniform; the frame does it so a frame size is uniform. <strong>Same decision, applied twice, in a format that has to keep sizes computable everywhere.</strong> It is also a good example of a rule that is invisible in the encoding and load-bearing in every consumer &mdash; nothing marks a <code>long</code> in the file as occupying two of anything; the rule lives entirely in how a reader counts.</p>
                <p>Next: <a href="/courses/jvm/lessons/jvm-code">the Code attribute</a> &mdash; where <code>max_locals</code> stops being about parameters, and the instructions themselves begin.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-strings">Previous: Modified UTF-8</a></span>
                <span><a href="/courses/jvm/lessons/jvm-code">Next: The Code Attribute</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
