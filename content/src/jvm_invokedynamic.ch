// JVM Course — Module 5: Linking and Versioning
// Concept: invokedynamic and bootstrap methods — the instruction whose target is
// computed at load time rather than named at compile time.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_invokedynamic() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("invokedynamic and Bootstraps — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>invokedynamic and Bootstraps</h1>
            <div class="lesson-meta">24 min &middot; Module 5: Linking and Versioning &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every other instruction in this course names its target. <code>invokestatic</code> has a method reference; <code>getfield</code> has a field reference; <code>new</code> has a class. The target is written into the constant pool at compile time and looked up when the method runs.</p>
                <p><code>invokedynamic</code> does not. It carries a bootstrap method index, and the <strong>actual call target is computed by running that bootstrap method the first time the instruction executes</strong>. The class file does not say what is called. It says what to call to find out what to call.</p>
                <p>This is the first point in the format where a class file is a <em>program</em> rather than a description. Everything before it was a layout the JVM could read and act on; <code>invokedynamic</code> makes the file contain instructions for constructing instructions. And it is the reason Java gained lambdas, method references, and &mdash; from Java 9 &mdash; string concatenation without changing the instruction set for either.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three pieces, and the middle one is the one that is not where a reader expects it.</p>
                <div class="formula">
1. the instruction, 5 bytes:
     u1 0xba                 invokedynamic
     u2 bootstrap_method_attr_index   a CONSTANT_InvokeDynamic
     u2 0                     two zero bytes, ALWAYS zero

2. the CONSTANT_InvokeDynamic entry, 4 bytes:
     u1 tag = 18
     u2 bootstrap_method_attr_index   -> into BootstrapMethods
     u2 name_and_type_index           the METHOD NAME and descriptor

3. the BootstrapMethods attribute:
     u2 num_bootstrap_methods
     then that many:
         u2 bootstrap_method_ref       ONE u2 -- a CONSTANT_MethodHandle
         u2 num_bootstrap_arguments
         u2 bootstrap_arguments[num_bootstrap_arguments]
</div>
                <p><strong>Point 3's single <code>u2</code> is the detail that costs an hour.</strong> Every other "reference to a method" in the format is a <code>CONSTANT_Methodref</code> &mdash; a class index and a name-and-type index, four bytes. A bootstrap method reference is <strong>one</strong> index, because it points at a <code>CONSTANT_MethodHandle</code> rather than a <code>CONSTANT_Methodref</code>. Reading two <code>u2</code>s there desynchronises the whole attribute immediately, and the resulting garbage looks structurally plausible for several entries before it fails.</p>
                <p>This course's own decoder made exactly that mistake. It read <code>method_ref</code> and then read a second <code>u2</code> as a name-and-type, and the result was a "number of arguments" of 134 in an 84-byte attribute &mdash; <strong>a value so obviously wrong that it was evidence, and the only reason it was noticed is that the attribute had to consume exactly 84 bytes.</strong></p>
                <p>And point 2 explains the division of labour. <strong>The <code>NameAndType</code> says what the call site is <em>called</em> and what signature it has; the bootstrap method says how to <em>compute</em> the target.</strong> For a lambda named <code>get</code> returning <code>Supplier</code>, the name and type are known at compile time and are what makes the call site's stack behaviour checkable. Everything else about the target &mdash; which class implements it, whether a synthetic class is generated at run time &mdash; is the bootstrap's problem.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>All 84 bytes of the <code>BootstrapMethods</code> attribute from <code>Lambda.class</code>, decoded. Nine entries, and this parse agrees with <code>javap</code> on all nine and consumes exactly 84 bytes:</p>
                <div class="hex-dump">
                    <pre>  [0] #174  3 args: #134 #135 #138     LambdaMetafactory
  [1] #174  3 args: #139 #140 #143     LambdaMetafactory
  [2] #174  3 args: #144 #145 #148     LambdaMetafactory
  [3] #174  3 args: #149 #150 #149     LambdaMetafactory
  [4] #174  3 args: #134 #153 #157     LambdaMetafactory
  [5] #174  3 args: #159 #160 #165     LambdaMetafactory
  [6] #181  1 args: #167               StringConcatFactory
  [7] #174  3 args: #134 #169 #138     LambdaMetafactory
  [8] #181  1 args: #172               StringConcatFactory

  0000: 00 09 00 ae 00 03 00 86 00 87 00 8a 00 ae 00 03
  0010: 00 8b 00 8c 00 8f 00 ae 00 03 00 90 00 91 00 94
  0020: 00 ae 00 03 00 95 00 96 00 95 00 ae 00 03 00 86
  0030: 00 99 00 9d 00 ae 00 03 00 9f 00 a0 00 a5 00 b5
  0040: 00 01 00 a7 00 ae 00 03 00 86 00 a9 00 8a 00 b5
  0050: 00 01 00 ac
</pre>
                </div>
                <p><strong>Two different bootstrap methods in one file</strong>, and that is the second finding. Entries 0&ndash;5 and 7 use <code>#174</code> = <code>LambdaMetafactory.metafactory</code>; entries 6 and 8 use <code>#181</code> = <code>StringConcatFactory.makeConcatWithConstants</code>. The same instruction, two entirely different mechanisms, chosen per call site. <strong>The class file does not say "this is a lambda"</strong> &mdash; it says "compute the target with this method, given these arguments", and what that means is the bootstrap's business.</p>
                <h3>The three arguments, and what each one is for</h3>
                <p>Take entry 0, which backs <code>#0:get:()Ljava/util/function/Supplier;</code>:</p>
                <div class="hex-dump">
                    <pre>  #134  MethodType   ()Ljava/lang/Object;        the ERASED signature
  #135  MethodHandle REF_invokeStatic Lambda.lambda$new$0:()Ljava/lang/String;
                                            the IMPLEMENTATION
  #138  MethodType   ()Ljava/lang/String;    the INSTANTIATED signature

  and the bootstrap method is called with three MORE parameters,
  which the file does not store because they come from the call site:

  (MethodHandles$Lookup, String name, MethodType type, ...)
</pre>
                </div>
                <p><strong>Three stored arguments plus four implicit ones, and the implicit ones are why the machinery is larger than the lambda.</strong> The <code>Lookup</code> carries the calling class's access rights, the <code>String</code> is the name from the <code>NameAndType</code>, and the first <code>MethodType</code> is the call site's descriptor. So the bootstrap receives the call site's context as parameters and the file's contribution as arguments, and it combines them to return a <code>CallSite</code> that the JVM links.</p>
                <p>The three stored ones are the parts the file genuinely has to record, and each has a job. <strong>The erased signature</strong> (#134) is what the call site was compiled against. <strong>The implementation handle</strong> (#135) points at the method that will actually run &mdash; a synthetic <code>lambda$new$0</code> in this case, which is a real method in the file with real code. <strong>The instantiated signature</strong> (#138) is what generic adaptation produced: the same method, reachable with a different type. That is <a href="/courses/jvm/lessons/jvm-signatures">generic erasure</a> being fixed up at load time rather than at compile time, and it is why <code>Supplier&lt;String&gt;</code> can be implemented by a <code>()Object</code> method.</p>
                <div class="callout callout-warn">
                    <strong>Entry 3 is the one that breaks the "javac generates a method" story.</strong> Its arguments are <code>#149 #150 #149</code> &mdash; erased type, <strong><code>REF_invokeStatic Lambda.hello:()V</code></strong>, same type again. <code>hello</code> is an <em>existing</em> method in the class, not a generated one. The source was a method reference like <code>Runnable r = this::hello;</code>, and <strong>javac pointed the bootstrap straight at the existing method rather than generating a trampoline</strong>. A method reference to an existing compatible method costs no new code at all; only a lambda whose body needs the arguments adapted gets a synthetic <code>lambda$new$N</code>. The naming scheme from <a href="/courses/jvm/lessons/jvm-inner-classes">the inner-class concept</a> reappears here &mdash; <code>lambda$new$0</code> is a <code>$</code> in a method name that has nothing to do with nesting, and the <code>$new$</code> infix is javac's marker for "generated for an object-creation lambda".
                </div>
                <h3>Entries 6 and 8: one argument, and a recipe</h3>
                <p>The two <code>StringConcatFactory</code> entries have <strong>one</strong> argument where the lambdas have three, and that single argument is a recipe string:</p>
                <div class="hex-dump">
                    <pre>  #7  InvokeDynamic #6:#53
       makeConcatWithConstants:(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
                                  +-- the DESCRIPTOR of the concatenation
  [6] #181  1 args: #167         #167 is the recipe Utf8

  [8] #181  1 args: #172         a 4-argument recipe for
       makeConcatWithConstants:(Ljava/lang/String;Ljava/lang/String;
                           Ljava/lang/String;Ljava/lang/String;Z)Ljava/lang/String;
</pre>
                </div>
                <p><strong>The recipe is a template with holes</strong> &mdash; literal text interleaved with references to the arguments, which is why a two-string concatenation has one argument and a four-string-plus-boolean has one. The descriptor tells the bootstrap how many values to expect and their types; the recipe tells it what to do with them. <strong>And this is the Java 9 string concatenation change: <code>"a" + b + "c"</code> no longer compiles to a <code>StringBuilder</code> chain, and the <code>makeConcat</code> bytecode from Java 8 does not appear in the file at all.</strong></p>
                <p>Two observations about that. The <code>StringBuilder</code> chain was <em>always</em> a fiction &mdash; the JIT has devirtualised and eliminated it for years, so the only cost was the class file size. Moving it to <code>invokedynamic</code> moved the recipe from bytecode the JVM had to interpret at JIT time into a constant the bootstrap interprets once. <strong>And it is the same mechanism serving a purpose that has nothing to do with lambdas</strong>, which is the strongest evidence that <code>invokedynamic</code> is a general linking facility rather than a lambda feature with a general name.</p>
                <h3>The instruction, and the method handle kinds</h3>
                <p>The instruction is five bytes and the last two are always zero:</p>
                <div class="hex-dump">
                    <pre>   5: invokedynamic #7,  0    // InvokeDynamic #0:get:()Ljava/util/function/Supplier;
  14: invokedynamic #17, 0    // InvokeDynamic #1:apply:()Ljava/util/function/Function;
  23: invokedynamic #25, 0    // InvokeDynamic #2:apply:()Ljava/util/function/BiFunction;
  32: invokedynamic #32, 0    // InvokeDynamic #3:run:()Ljava/lang/Runnable;
</pre>
                </div>
                <p><strong>Those two zero bytes are reserved and always zero</strong>, and they are the only part of the instruction whose purpose is not obvious from the name. They exist because a later revision of the instruction needed the space; the format's usual answer to "we might want this" is to reserve bits rather than to version the opcode.</p>
                <p>And the method handle reference kinds in that attribute &mdash; a <code>u1</code> on the <code>CONSTANT_MethodHandle</code> &mdash; cover nine access modes that no other instruction uses:</p>
                <div class="hex-dump">
                    <pre>  1 REF_getField         6 REF_invokeStatic
  2 REF_getStatic        7 REF_invokeSpecial
  3 REF_putField         8 REF_newInvokeSpecial
  4 REF_putStatic        9 REF_invokeInterface

  seen here:
    6 REF_invokeStatic   Lambda.lambda$new$0     the lambda body
    6 REF_invokeStatic   java/lang/invoke/LambdaMetafactory.metafactory
    6 REF_invokeStatic   java/lang/invoke/StringConcatFactory.makeConcatWithConstants
    8 REF_newInvokeSpecial java/util/ArrayList."&lt;init&gt;"
    5 REF_invokeVirtual  java/lang/String.isEmpty
</pre>
                </div>
                <p><strong>Method handles are a second, richer reference form than the method references the other instructions use</strong> &mdash; nine kinds instead of four, covering field access and construction as well as invocation. That is a deliberate widening: a method handle can name a field or a constructor, so a bootstrap method can be handed "the getter for this field" and use it, and <code>LambdaMetafactory</code> does exactly that when adapting an implementation.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a lambda actually costs, which is the number nobody expects, and the reason the metafactory has that six-parameter signature:</p>
                <div class="formula">
  ONE lambda, `() -> "hi"`, measured in Lambda.class:

    1  the invokedynamic instruction            5 bytes
    1  CONSTANT_InvokeDynamic                  4 bytes
    1  CONSTANT_NameAndType                    4 bytes
    1  the NameAndType's two Utf8 entries    ~12 bytes
    1  BootstrapMethods entry                  10 bytes
    3  arguments: 2 MethodTypes + 1 MethodHandle
       3 CONSTANT_MethodType                   12 bytes
    1  CONSTANT_MethodHandle                   4 bytes
    1  NameAndType for the handle              4 bytes
    1  Utf8 for the impl's descriptor        ~10 bytes
    1  the synthetic method lambda$new$0       ~20 bytes of CODE
    -- plus the class it is in, and at RUN TIME
    1  a generated hidden class per lambda    ~1 KB, generated
                                          ---------
    the source was 11 characters.
</div>
                <p><strong>The mechanism is more than the feature, by roughly two orders of magnitude.</strong> That is not a criticism of the design &mdash; it is what buying late binding costs, and the alternative at the time was either no lambdas or generating a class per lambda at <em>compile</em> time, which would have made the file even larger and fixed the target at compile time. The trade is: <strong>pay at load time, once, and pay in bytes, in exchange for the target not being fixed until it runs.</strong></p>
                <p>And the <code>CallSite</code> is the part that makes the late binding actually work. <strong>A <code>CallSite</code> is a mutable object holding a target, and the instruction reads it at execution time.</strong> The first execution runs the bootstrap and installs a target; every later execution is a virtual call through the now-populated site, which the JIT can inline exactly as it would any monomorphic call site. So the expensive path runs once and the hot path is a direct call &mdash; <strong>the same "pay at load, keep the hot path direct" bargain the nest attributes in <a href="/courses/jvm/lessons/jvm-inner-classes">Module 3</a> made for private field access</strong>, and it is why <code>invokedynamic</code> is fast despite the machinery.</p>
                <p>Now the honest cost, because it is real and it is why this feature has a reputation. <strong>Each distinct lambda call site gets its own generated class at run time</strong>, and that class is loaded into the same metaspace as any other. A program with a hundred thousand distinct lambdas pays a hundred thousand class loads, and the failure mode is <code>OutOfMemoryError: Metaspace</code> rather than an allocation failure. The JVM has mitigations &mdash; a hidden class is not retained by a class loader's strong reference set, so it can be collected when the call site becomes unreachable, and lambdas that do not capture anything are cached &mdash; but the shape of the cost is real and worth knowing before reaching for lambdas in a hot path.</p>
                <p>What <code>invokedynamic</code> bought, in one list. <strong>Lambdas</strong> and <strong>method references</strong> with no new instruction and no new class format &mdash; Java 8. <strong>String concatenation</strong> via <code>StringConcatFactory</code>, retiring a bytecode pattern &mdash; Java 9. And a general facility: any language compiling to the JVM can now <strong>define its own runtime-generated constructs</strong> by writing a bootstrap method, without asking the JVM for a new opcode. Kotlin's <code>inline</code> reification, Scala's implicit macros, and Clojure's <code>reify</code> are all built on it. <strong>That is the design's real significance &mdash; the class file became extensible at the instruction level, twenty years after it was extensible at the attribute level.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Lambda.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Lambda.class</code></pre>
                <ul>
                    <li><strong>Decode the 84 bytes by hand with the one-<code>u2</code> rule.</strong> Nine entries, and the arithmetic has to come to exactly 84. <strong>Read it as two <code>u2</code>s first and watch the argument count come out as 134</strong> &mdash; and then notice that the attribute length is the only thing that tells you, which is the argument for always asserting the parse consumed exactly the declared length.</li>
                    <li><strong>Write the two-zero-byte check.</strong> Parse the <code>invokedynamic</code> instructions and assert bytes 3&ndash;4 are zero. <strong>Find one that is not</strong>, and you have found a class file from a JVM extension that chose to use the reserved space &mdash; which is a good way to see what the reservation is actually for.</li>
                    <li><strong>Compare a lambda with a method reference.</strong> <code>() -> hello()</code> against <code>this::hello</code> where <code>hello</code> already takes no arguments. <strong>One generates a synthetic <code>lambda$new$0</code>, the other points straight at the existing method</strong> &mdash; and the bootstrap argument list shows it as a handle to a real method instead of a handle to a generated one.</li>
                    <li><strong>Count a lambda's bytes.</strong> The arithmetic in the example above is a starting point; do it properly by diffing two files that differ by one lambda. <strong>The marginal cost is measurable and it is much larger than the source</strong>, which is the finding worth keeping.</li>
                    <li><strong>Find the string-concat recipe.</strong> Print the <code>Utf8</code> at index 167 and read it as a template. <strong>Then compile the same concatenation with <code>--release 8</code> and watch a <code>StringBuilder</code> chain replace it</strong> &mdash; the same source, two completely different bytecode, one instruction apart in the language's history.</li>
                    <li><strong>Write a bootstrap method.</strong> A static method with the four implicit parameters returning a <code>ConstantCallSite</code>, a <code>CONSTANT_InvokeDynamic</code> entry pointing at it, and a <code>BootstrapMethods</code> entry. <strong>Invoke it and print what your own bootstrap received</strong> &mdash; the <code>Lookup</code>, the name, the call-site type, and your own arguments, and seeing them arrive is the concept made concrete.</li>
                    <li><strong>Watch the linking happen.</strong> Set a breakpoint in your bootstrap method and step through the first execution of the <code>invokedynamic</code>. <strong>The bootstrap runs once and the instruction then goes straight through the call site</strong> &mdash; which is the "pay at load, direct on the hot path" bargain, observed rather than argued.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you are parsing the <code>BootstrapMethods</code> attribute and you read a bootstrap method reference as <code>#174</code> followed by a second <code>u2</code> of <code>0x0003</code>, then read that second value as the argument count and start reading 134 arguments from an 84-byte attribute. What did you read wrong, and what is the general reason this particular field is one <code>u2</code> when every other method reference in the format is two?</p>
                <div class="quiz" id="quiz-jvm-invokedynamic-1">
                    <button class="quiz-option" data-correct="true" data-explain="The second u2 is not a second half of a reference at all -- it is the argument count, and it happens to be three because this entry has three arguments. So the parse desynchronised by exactly two bytes per entry, and the first symptom is a count of 134 read out of a value that was never a count. The reason the reference is one u2 is that a bootstrap method is named by a CONSTANT_MethodHandle, not a CONSTANT_Methodref, and a MethodHandle pool entry is already a complete reference: one access-kind byte plus one index, resolved, so the class and the name-and-type are baked into the handle's target rather than supplied separately here. Every other method reference in the format is a Methodref because those instructions need a class index and a name-and-type index as two separate things, and a bootstrap method reference does not, because a method handle is a first-class resolved reference. The general lesson is about how the failure presents rather than about the field: the misparse did not produce a negative number or a wild pointer, it produced a plausible small integer and then a run of indices that look like perfectly reasonable pool entries. Only the attribute length reveals it. That is why asserting that a parse consumed exactly the declared number of bytes is not a defensive nicety but the primary correctness check for any length-delimited structure." onclick="checkQuiz('quiz-jvm-invokedynamic-1', this)">The second <code>u2</code> is the argument count, not half a reference &mdash; and it reads 134 because the parse is already desynchronised. A bootstrap method is named by a <code>CONSTANT_MethodHandle</code>, which is a complete reference on its own, unlike a <code>CONSTANT_Methodref</code> which needs a class index and a name-and-type index as two <code>u2</code>s</button>
                    <button class="quiz-option" data-correct="false" data-explain="The diagnosis is right about the field's width and wrong about what the reference points at, and the difference matters because it determines whether the value is even legal. A bootstrap method reference is not a Methodref written short; it is a MethodHandle, which is a different pool tag with different structure and different semantics -- a kind byte plus a Methodref index -- and the specification names it that way because the bootstrap method is invoked through a method handle rather than through a direct method reference. Reading it as a Methodref would be a different bug from the one described, and the two-byte desync would not be the same shape: a Methodref consumes a class index and a name-and-type index, and after those comes the argument count, so the parse would read three u2s where there are two and the offset error would be different rather than identical. The practical reason MethodHandle is used is capability-based: a handle carries an access kind, so the receiver of a handle can only perform the access it was granted, and the bootstrap framework is built on that. A plain Methodref grants access to the whole class." onclick="checkQuiz('quiz-jvm-invokedynamic-1', this)">The reference is one <code>u2</code> because a bootstrap method is a method in a class and the class is implied by the <code>NameAndType</code> that follows it, so the format omits the redundant class index. The parser should have read <code>#174</code> and then a separate argument count, and the 134 is the count read from a field that was never a count</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a bytecode-level verifier. It checks that every <code>invokedynamic</code> instruction's bootstrap index is in range and that the <code>NameAndType</code> descriptor matches the values actually on the stack at that point. It passes every class in the JDK's own modules. A tool you run later on a third-party class reports "descriptor mismatch: expected one argument, found zero" on a class that loads and runs correctly on the same JVM. What is the check getting wrong, and what is the strongest evidence in the situation that it is the check and not the class?</p>
                <div class="quiz" id="quiz-jvm-invokedynamic-2">
                    <button class="quiz-option" data-correct="true" data-explain="The check is validating the wrong thing, and the reason is that an invokedynamic's descriptor is a claim about the call site's stack effect, not a description of what the bootstrap does. The JVM checks the former -- the name-and-type must match the operand stack at the instruction, which is why a mismatch is a verification failure -- and that is exactly what the tool is doing. But the tool is inferring the expected argument count from the bootstrap method's descriptor, and those are different things. LambdaMetafactory's descriptor takes six parameters, of which the first three are supplied implicitly by the call site and the last three come from the bootstrap arguments, so counting its parameters gives a number with no relationship to how many values are on the stack at the invokedynamic. The evidence that the check is wrong rather than the class is overwhelming and comes in three independent parts. It passes every class the JDK itself ships, and the JDK is the producer of the majority of invokedynamic sites in existence. It fails on a class that loads and runs correctly on the same JVM, so the JVM's own verifier accepts what the tool rejects. And the failure is a mismatch rather than a crash, so the tool parsed the structure successfully and then judged it -- which means the length and the offsets are right and only the semantic expectation is wrong. The general habit is to know which of a format's fields is a promise to the machine and which is a hint to a reader, and to verify only the former." onclick="checkQuiz('quiz-jvm-invokedynamic-2', this)">The check is inferring the expected argument count from the bootstrap method's descriptor, but the descriptor is a claim about the <em>call site's stack effect</em>, not about what the bootstrap consumes &mdash; <code>LambdaMetafactory.metafactory</code> has six parameters of which three are supplied implicitly. The class passing on the real JVM plus the whole JDK passing are the decisive evidence</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a plausible and wrong diagnosis, and the whole JDK passing is what rules it out. If the tool's notion of the descriptor's meaning were inverted -- counting declared parameters where the call site pushes arguments, or vice versa -- then every invokedynamic in every class the JDK ships would fail the same way, and lambdas and string concatenation are everywhere in the JDK. The failure would be universal rather than isolated to one third-party class, which is the opposite of what is reported. Nor does it explain the specific shape of the complaint: a mismatch between an expected argument count and an observed one, which means the tool successfully read a descriptor, successfully read an expected count from somewhere, and successfully compared them. An inverted convention would more likely produce a systematically wrong count that disagrees with almost every class, not a disagreement on one. The class is fine; the tool has built its expectation from the wrong field." onclick="checkQuiz('quiz-jvm-invokedynamic-2', this)">The check has the direction of the descriptor's meaning inverted &mdash; it is counting the bootstrap method's declared parameters where it should count the call site's stack values, so the class's descriptor is being read with the wrong convention</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: in a format where several fields describe the same construct, know which one is a promise the machine will enforce and which is a hint. Verify the promise; treat the hint as unverified until something independent confirms it.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>A class file that computes its own instructions is the same idea as a <a href="/courses/elf/lessons/relocation-entries">relocation</a>, and seeing the two side by side sharpens both. An ELF relocation says <em>a symbol's address goes here</em> and the loader fills it in; an <code>invokedynamic</code> says <em>compute a target with this method and these arguments</em> and the JVM links it on first execution. <strong>Both defer work past compile time, and both exist because the compiler cannot know the answer</strong> &mdash; a symbol's address for a relocation, a lambda's target for an <code>invokedynamic</code>. The difference is the amount of computation permitted: a relocation gets a number written into a word, and an <code>invokedynamic</code> gets arbitrary Java code run once. <strong>A relocation is a fixed-point operation; a bootstrap is a program.</strong></p>
                <p>The method handle is where this connects to <a href="/courses/pe/lessons/pe-load-config">a PE's load config</a> and to <a href="/courses/coff/lessons/coff-weak-externals">COFF weak externals</a>, because a handle is a <em>capability</em>: it names a target and the access kind permitted on it, and the holder of a handle cannot do more than the handle allows. <strong>That is the same property as control flow guard or a weak reference resolving to nothing &mdash; a grant, not a description</strong>, and the JDK's whole <code>MethodHandles</code> and <code>VarHandle</code> API is built on the idea that a reference can be narrowed to exactly the access it needs. Compare a <code>CONSTANT_Methodref</code>, which grants access to every public member of its class: a handle is the narrower of the two, and bootstrap methods receive handles precisely so the capability can be passed along.</p>
                <p>The reserved two zero bytes are a <a href="/courses/elf/lessons/elf-identification">format's</a> oldest habit. <a href="/courses/elf/lessons/section-vs-segment">ELF's <code>e_shnum</code></a> is zero to mean "the real count is in section zero's size field", and several <a href="/courses/pe/lessons/pe-optional-header">PE optional header</a> fields use zero as an escape to a nearby field. <strong>Every format reserves a sentinel when it is not sure what it will need, and every one of those sentinels has eventually been used</strong> &mdash; which is the strongest argument for reserving space in a format you cannot change, and the strongest argument against assuming a reserved field will stay reserved.</p>
                <p>The attribute inventory from <a href="/courses/jvm/lessons/jvm-attributes">the escape hatch</a> listed <code>BootstrapMethods</code> at four occurrences across 24 samples, and it is worth noticing that it is the one common attribute that is <em>not</em> inert. <code>SourceFile</code> can be skipped freely; <code>BootstrapMethods</code> cannot be skipped by anything that executes the class, because every <code>invokedynamic</code> in the file needs it. <strong>An attribute's safety to skip is not uniform across the format, and this is the attribute where skipping stops being free.</strong> The qualification to "skip what you do not understand" that the <a href="/courses/jvm/lessons/jvm-sealed">sealed types concept</a> raised is the same one, from the other direction: the attributes that carry meaning a machine acts on are the ones a verifier cannot treat as opaque.</p>
                <p>Next: <a href="/courses/jvm/lessons/jvm-modules">modules</a>, the last structural feature the format added and the one that finally used two constant pool tags that <code>javap</code> still labels <code>Unknown</code> &mdash; which makes it the natural place to end the structural tour before <a href="/courses/jvm/lessons/jvm-versions">the version history</a> puts the whole format in order.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-enums">Previous: Enums</a></span>
                <span><a href="/courses/jvm/lessons/jvm-modules">Next: Modules</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
