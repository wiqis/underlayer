// JVM Course — Module 2: Members and Code
// Concept: StackMapTable — why a type checker writes its conclusions into the
// file, and what the frame types compress.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_stackmaps() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Verifier's Data — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>The Verifier's Data</h1>
            <div class="lesson-meta">23 min &middot; Module 2: Members and Code &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is a genuinely strange thing about the class file format, and it is worth stating plainly before anything else: <strong>a compiler writes down the result of a type-checking analysis, in the file, where a verifier will check it.</strong> Not the code &mdash; the code is there to be executed. The <em>conclusions</em> are also there, as data, so that the virtual machine can check them cheaply.</p>
                <p>The reason is a performance argument with a long history behind it. Before Java 6, the JVM verified bytecode by executing an abstract interpretation of it: it walked every instruction, tracked the type of every stack slot, and proved the method type-safe. That is sound and it is slow. <strong>Proving that a method is safe costs time proportional to the code, on every class, once per class loaded</strong> &mdash; and the result does not depend on anything at run time.</p>
                <p>So the conclusion was hoisted out of the loop. The compiler, which has already done the analysis, writes a <code>StackMapTable</code> saying &ldquo;at this offset, the frame is in this state&rdquo;, and the verifier's job drops from <em>proving</em> to <em>checking</em> &mdash; following the frames and confirming each one is reachable and consistent. That is a large constant-factor win, and it is why the table exists. <strong>The price is that the file now contains a claim about the code, and the verifier's job has changed from proving the claim to trusting-with-checks.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What a frame is, and then how the table encodes a sequence of them:</p>
                <div class="formula">
a FRAME at some point in the code is:

    locals[0 .. max_locals)      each slot holds a type
    stack[0 .. stack_depth)      each entry holds a type

  and a StackMapTable is a list of frames at chosen offsets:

    u2 number_of_entries
    then that many frames

  the frames are stored as DIFFERENCES from each other, and each
  frame_type byte says which of several shapes this frame is:
</div>
                <p>There are fifteen frame types, and they are not fifteen different kinds of frame. <strong>They are fifteen ways of saying &ldquo;here is what changed since the last one&rdquo;.</strong> The first frame is special because there is no previous one.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Type</th><th scope="col">Range</th><th scope="col">Means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>same_frame</code></td><td>0&ndash;63</td><td>nothing changed; the frame_type <em>is</em> the offset</td></tr>
                        <tr><td><code>same_locals_1_stack_item</code></td><td>64&ndash;127</td><td>locals unchanged, stack depth is 1; frame_type minus 64 is the offset delta</td></tr>
                        <tr><td><code>same_locals_1_stack_item_extended</code></td><td>247</td><td>as above, with a full 16-bit delta</td></tr>
                        <tr><td><code>chop_frame</code></td><td>248&ndash;250</td><td>locals unchanged, stack is empty, and 1 to 3 locals were chopped</td></tr>
                        <tr><td><code>same_frame_extended</code></td><td>251</td><td>nothing changed, with a full 16-bit delta</td></tr>
                        <tr><td><code>append_frame</code></td><td>252&ndash;254</td><td>locals unchanged, stack empty, 1 to 3 locals appended</td></tr>
                        <tr><td><code>full_frame</code></td><td>255</td><td>everything restated: all locals, then the stack</td></tr>
                    </tbody>
                </table>
                <p><strong>The compression is the whole design, and it is a delta encoding against the previous frame.</strong> A <code>same_frame</code> costs one byte and says nothing at all &mdash; the verifier already knows the state, because the previous frame told it and nothing has changed. That is what makes the table small enough to be worth having: most branch targets in real code are reached with the locals unchanged, because most branches are loops and conditionals that do not touch the frame.</p>
                <p>And the range allocation is doing real work. <strong>Types 0 to 63 are free offsets</strong>, which covers small methods entirely in one byte per frame. <strong>64 to 127 cost one byte of offset and buy a one-item stack</strong>, which is the single most common change in practice: a branch that just stored something. Everything else needs a second byte, and the two <code>_extended</code> types exist only because a method longer than 127 bytes runs out of the one-byte range.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The <code>tableswitch</code> method's table, in full. Eight bytes for six frames, and every byte accounted for:</p>
                <div class="hex-dump">
                    <pre>  00 06 24 01 01 01 01 01
    |  |  |  |  |  |  +-- frame 5: 0x01
    |  |  |  |  |  +----- frame 4: 0x01
    |  |  |  |  +-------- frame 3: 0x01
    |  |  |  +----------- frame 2: 0x01
    |  |  +-------------- frame 1: 0x01
    |  +----------------- frame 0: 0x24 = 36, a same_frame at 36
    +-------------------- 6 frames
</pre>
                </div>
                <p>Six <code>same_frame</code>s at one byte each. And here is the arithmetic, which is the detail that makes the encoding click:</p>
                <div class="formula">
frame 0:  offset = 36                       (0x24, the frame_type IS the offset)
frame 1:  offset = 36 + 1 + 1 = 38         (0x01, and the +1 is the rule)
frame 2:  offset = 38 + 1 + 1 = 40
frame 3:  offset = 42
frame 4:  offset = 44
frame 5:  offset = 46
</div>
                <p><strong>Why the <code>+1</code>.</strong> Every frame after the first is stored as a delta from the previous frame's offset, and the delta is <em>one less</em> than the actual difference. The reason is that a delta of zero would be ambiguous: <code>0x00</code> is <code>same_frame</code> with a zero delta, which would mean two frames at the same offset. Subtracting one makes every real difference representable in one byte, and it means a <code>same_frame</code> at the very next instruction has a delta of zero &mdash; which is legal and which is exactly what a loop back to the following instruction looks like.</p>
                <p>And the payoff is the cross-check from the previous concept. Those six frame offsets are <strong>36, 38, 40, 42, 44, 46</strong>, and the switch's six destinations are <strong>36, 38, 40, 42, 44, 46</strong> &mdash; the five cases plus the default, derived independently, matching to the byte. <strong>Six frames for six branch targets, one byte each, because at every one of those points the frame is identical to the one before.</strong></p>
                <h3>What a frame that has to say something looks like</h3>
                <p>The <code>trycatch</code> method, where the frames are <code>same_locals_1_stack_item</code> and so carry a type. Fourteen bytes for three frames:</p>
                <div class="hex-dump">
                    <pre>  00 03 4a 07 00 07  47 07 00 09  48 07 00 15
    |  |  |  |  |  |  +------- 0x0015 = 21 -> Throwable
    |  |  |  |  |  +---------- 0x07: an OBJECT type
    |  |  |  |  +------------- 0x48 = 72, a same_locals_1_stack_item
    |  |  |  +--------------- 0x0009 -> RuntimeException
    |  |  +------------------ 0x07: an OBJECT type
    |  +--------------------- 0x47 = 71, a same_locals_1_stack_item
    |  +----------------------- 0x0007 -> ArithmeticException
    +-------------------------- 0x07: an OBJECT type
    +---------------------------- 0x4a = 74, a same_locals_1_stack_item
    +------------------------------ 3 frames
</pre>
                </div>
                <p>The structure of each entry is three bytes of overhead plus a type: a one-byte frame type, then a <em>verification type</em> consisting of a one-byte tag and a two-byte pool index. And the three frame types, 74, 71 and 72, have to be read as <strong>64 plus an offset delta</strong>:</p>
                <div class="hex-dump">
                    <pre>  frame 0:  74 - 64 = 10  -> offset 10        ArithmeticException
  frame 1:  71 - 64 =  7  -> 10 + 7 + 1 = 18  RuntimeException
  frame 2:  72 - 64 =  8  -> 18 + 8 + 1 = 27  Throwable
</pre>
                </div>
                <p>And those three offsets are <strong>10, 18 and 27 &mdash; the three exception handler targets from the previous concept, exactly</strong>. So the frames are the type checker's note that at each handler, the stack holds one value of the caught type, and the locals are whatever they were.</p>
                <div class="callout callout-warn">
                    <strong>A hypothesis this course formed, tested, and had to discard.</strong> Seeing 74, 71 and 72 as raw bytes gives 0x4A, 0x47, 0x48 &mdash; and those are the <code>astore</code>, <code>astore_0</code> and <code>astore_1</code> opcodes. That is a coincidence worth chasing, because the specification really does say a <code>same_locals_1_stack_item</code> frame always follows an astore-family instruction, and the frame's single stack item is whatever that store put there. The connection looked like a lovely piece of encoding economy: the frame type <em>is</em> the instruction that produced the item, so the verifier does not have to be told twice. <strong>It is wrong, and the bytes say so.</strong> The instructions at offsets 10, 18 and 27 in that method are <code>astore_2</code>, <code>astore_2</code> and <code>astore 4</code> &mdash; opcodes 0x4D, 0x4D and 0x3A, none of which is 0x4A, 0x47 or 0x48. The frame type is 64 plus an offset delta and nothing else; the astore opcodes merely occupy the same numeric range. <strong>Recording this matters more than the finding it replaced, because a plausible story that survives a glance is exactly what this course keeps warning about</strong> &mdash; the 64-to-127 range was allocated to this frame type, and the astore family happens to live at 64 to 127 too, and those two facts are unrelated.
                </div>
                <h3>The verification type tags</h3>
                <p>The second half of a frame entry is a type, and its tag byte is a second, smaller tag space:</p>
                <div class="hex-dump">
                    <pre>  tag  meaning
    0   TOP                 the unusable half of a long or double
    1   INTEGER             int, short, byte, char, boolean
    2   FLOAT
    3   DOUBLE
    4   LONG
    5   NULL                the type of a null reference
    6   UNINITIALIZED_THIS  in a constructor, before super() runs
    7   OBJECT              + a u2 pool index to a Class
    8   UNINITIALIZED      + a u2 offset: a new that has not completed
</pre>
                </div>
                <p>Two of those are worth pausing on, because they are the verifier's internal states leaking into the file.</p>
                <p><strong><code>TOP</code> is the unusable half of a 64-bit value</strong> &mdash; the same two-slot rule a third time. A <code>long</code> occupies two local slots, the second holds no value, and the type checker needs a name for that slot, so it invents one and writes it in the file. <strong>It is the local-frame twin of the constant pool's second index</strong>, and the reason is the same: a 64-bit value is two 32-bit units, and everything that tracks such a value has to account for both.</p>
                <p>And <strong><code>UNINITIALIZED_THIS</code> exists because of a language rule, not a machine one.</strong> Java requires a superclass constructor to run before the object is usable, so the verifier tracks an object whose superclass constructor has not yet been called. The source is <code>super()</code> being mandatory as the first statement of a constructor, and it is the reason a verifier exists at all: <strong>without the check, a subclass could read a field before the superclass set it, and the failure would be a silent wrong value rather than a crash.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What the verifier actually does with the table, and why the change from proving to checking is safe:</p>
                <div class="formula">
<pre>verify(method):

    # NOT: walk every instruction tracking every type
    #      (that is the pre-Java-6 verifier, and it is what this
    #       table exists to avoid)

    frame = implicit_initial_frame()     # from the descriptor
    pending_targets = every branch destination in the method

    for each frame in the StackMapTable:
        offset = frame.offset
        assert offset is in pending_targets
            the table must only claim positions the code
            actually branches to. A frame anywhere else is
            rejected -- it is a claim about a path that does
            not exist.

        # apply the DELTA, not a description
        frame.locals = previous.locals + frame's local changes
        frame.stack  = previous.stack  + frame's stack changes

        walk the code from the last frame's offset to here,
        simulating only the INSTRUCTIONS, and check that the
        simulation arrives at exactly the state the frame claims

        pending_targets -= destinations inside the range just walked

    assert pending_targets is empty
        every branch in the method was covered by some frame
</pre>
                </div>
                <p>Three assertions in that, and each one is a place a malformed file is caught. <strong>The table may only claim positions that are real branch targets</strong>, so a table that describes a path the code does not have is rejected rather than ignored. <strong>The simulation must agree with the claim</strong> &mdash; so the table cannot assert a type the code would not produce, which means a compiler cannot lie about a method being safe when it is not. And <strong>every branch must be covered</strong>, so omitting a frame for a real target is an error rather than a gap.</p>
                <p>That last one is what stops the whole scheme from being a security hole. If a method contained a branch target with no frame, a lazy verifier would simply not check it &mdash; and the method's type safety would rest on nothing. So the verifier's first act is to enumerate the branch targets itself, independently, and then require the table to match. <strong>It is a checksum over the control-flow graph, written by the compiler and verified by the machine</strong>, and that is why the table can be trusted to have skipped nothing.</p>
                <p>Why the delta encoding is safe is the more interesting question, and the answer is that it is not a claim about <em>correctness</em> at all &mdash; only about <em>effort</em>. A <code>full_frame</code> restates the locals, so a table of only full frames would carry exactly the same information in more bytes. The deltas are a compression with no loss, and they are safe because the verifier reconstructs the full state before checking anything against it. <strong>What changed in Java 6 was not what the verifier knows; it is how much work the compiler does to let the verifier skip.</strong></p>
                <p>And the cost falls on the producer, which is worth naming because it is unusual. <strong>The class file is now larger</strong> &mdash; a <code>StackMapTable</code> is a real cost in every method with a branch. <strong>And the compiler must compute the frames even when nothing will ever verify the result</strong>, because the table is not optional for a version 50 or later class file. A tool that generates class files has to implement the analysis whether or not it cares about type safety, which is why class file generators are rare and bytecode libraries are not.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Shapes.class
$ python3 courses/jvm/assets/samples/class_decode.py out/Shapes.class</code></pre>
                <ul>
                    <li><strong>Decode the eight-byte table by hand.</strong> Six frames, six bytes, and the <code>+1</code> rule. <strong>Write down all six offsets before looking at the code</strong>, then check each one lands on an instruction boundary &mdash; and notice that if you forget the <code>+1</code> they will not, which is the fastest way to see why the rule exists.</li>
                    <li><strong>Find a table that has to use the other frame types.</strong> A method with locals that change across a branch needs a <code>chop_frame</code> or an <code>append_frame</code>; a method that pushes more than one value needs a <code>full_frame</code>. <strong>Write both and read the frame types back</strong> &mdash; seeing 248 and 255 in the bytes makes the range table concrete in a way that reading it does not.</li>
                    <li><strong>Find a table long enough to need an <code>_extended</code> type.</strong> A method over 127 bytes with many branches, or a branch over 127 bytes forward. <strong>Confirm the frame type jumps to 247 or 251</strong>, and work out what the extra two bytes bought.</li>
                    <li><strong>Compare a table with and without <code>-g:none</code>.</strong> The debug flags should not affect the stack map, because it is not debug information &mdash; <strong>check whether they do, and if the size is identical, that is the evidence that this attribute is load-bearing rather than optional.</strong></li>
                    <li><strong>Find an <code>UNINITIALIZED_THIS</code> frame.</strong> Any constructor, and a class with a superclass. <strong>The frame appears before the <code>invokespecial</code> that runs the superclass constructor and disappears after</strong> &mdash; reading that pair makes the language rule visible in the file.</li>
                    <li><strong>Prove the branch-coverage rule by breaking it.</strong> Delete one frame from a table, and see what the verifier says. <strong>Then change a frame's offset to a position that is not a branch target</strong>, and see that rejected too. Two rejections, and together they are the argument for why the table can be trusted.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a method's <code>StackMapTable</code> holds six frames, all <code>same_frame</code>, with frame type bytes <code>36, 1, 1, 1, 1, 1</code>. What are the six frame offsets, how many bytes does the whole table occupy, and what does the fact that all six are <code>same_frame</code> tell you about those six points in the code?</p>
                <div class="quiz" id="quiz-jvm-stackmaps-1">
                    <button class="quiz-option" data-correct="true" data-explain="Three parts, and the last is the interesting one. The first frame's frame_type is its offset directly, because there is no previous frame to be a delta from, so it sits at 36. Every later frame is a delta from the previous offset and the stored value is one less than the true difference, which is why each of the five delta bytes is 1 rather than 0: 36 plus 1 plus 1 gives 38, then 40, 42, 44, 46. The table occupies eight bytes, two for the count and one for each of the six frames, and there is no other content because a same_frame carries no type information at all. What the frame types tell you is that the frame is identical to the previous one at all six points, and that is the compression working: the verifier already knew the state, so each frame only had to say where it was. In this method the six points are the six branch destinations of a switch, and a switch that jumps to code that just pushes a constant and returns does not disturb the frame at all, so every one of them is a same_frame. That is why a six-way switch costs six bytes of verification data rather than six full frame descriptions." onclick="checkQuiz('quiz-jvm-stackmaps-1', this)">Offsets 36, 38, 40, 42, 44 and 46 &mdash; the first frame type is the offset, and each later one adds its stored value plus one. The table is 8 bytes: 2 for the count and 1 per frame. All six being <code>same_frame</code> means the frame is unchanged at every branch target, which is the delta encoding doing its job</button>
                    <button class="quiz-option" data-correct="false" data-explain="The count is right and the arithmetic is wrong in a way that is worth being precise about, because the error produces offsets that are still plausible. Each later frame does not add one to the previous offset; it adds the stored value plus one, where the stored value is the frame_type. So a frame_type of 1 means a delta of 1, giving a difference of 2, not a difference of 1. Applying the stored value directly would give 36, 37, 38, 39, 40, 41, and the tell is that those come out consecutive and odd-and-even mixed rather than landing on the even instruction boundaries the switch actually targets. The subtraction exists so that a delta of zero is available, which is what a frame at the very next instruction needs, and without it that case would be indistinguishable from a same_frame at the same offset." onclick="checkQuiz('quiz-jvm-stackmaps-1', this)">Offsets 36, 37, 38, 39, 40 and 41, with the table occupying 8 bytes. All six being <code>same_frame</code> means the verifier must restate the locals at each one</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A third-party bytecode library generates class files. Everything works until it hits a method with more than 127 bytes of code containing a forward branch. At that point the JVM rejects the class with <code>Expecting a stackmap frame at branch target</code>. Methods under that size are fine, including ones with branches. The library was written against a version 50 target. What is the defect, and what is the change that fixes it that is <em>not</em> simply &ldquo;emit more frames&rdquo;?</p>
                <div class="quiz" id="quiz-jvm-stackmaps-2">
                    <button class="quiz-option" data-correct="true" data-explain="The threshold in the report is the diagnosis. The one-byte frame type encodes an offset delta in the range 0 to 63 for a same_frame and 64 to 127 for a same_locals_1_stack_item, so a delta beyond 63 simply has no one-byte encoding, and a method that branches further than that needs one of the two extended types, 247 and 251, which carry a full sixteen-bit delta after the tag. The library is emitting the compact form unconditionally because every method it has been tested on fits, so it is the same class of bug as the wasm-ld and huffman cases in this course: a tool that is correct on the data you tested it with and silently wrong on the boundary. The fix is not more frames but choosing the frame type from the delta's value, falling back to the extended form when it does not fit, and that is a genuinely different piece of logic rather than a matter of emitting more. The broader point is that a range-limited encoding has a threshold, and a producer that never crosses the threshold has no evidence its encoding logic is right; the only way to find out is to construct the case that crosses it deliberately." onclick="checkQuiz('quiz-jvm-stackmaps-2', this)">The frame type is a one-byte offset delta with a maximum range, and a branch further than 63 bytes has no one-byte encoding, so the library must fall back to the <code>same_frame_extended</code> or <code>same_locals_1_stack_item_extended</code> forms with a 16-bit delta. It is emitting the compact form unconditionally, which is correct on everything it has been tested on and wrong past the threshold</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is worth ruling out and the size threshold argues against it, though the reasoning is subtler than it first looks. A missing frame would be rejected with a message about a branch target that has no frame, and the library is emitting frames for every branch target it can see; the failures start exactly where a particular frame type stops being encodable, not where a frame is missing. Omitting the table entirely would be a different failure again, and one that would affect small methods too, since the table is required for these class file versions regardless of size. The correlation with method size is the whole clue: something about a large method's encoding differs, and the only thing that changes with distance is how a delta is represented." onclick="checkQuiz('quiz-jvm-stackmaps-2', this)">The library is not computing stack map frames for branches at all, so any method with a forward branch is missing them, and the size correlation is incidental because larger methods are more likely to branch forward</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a range-limited encoding has a threshold, and a producer that has never crossed it has no evidence its logic is right. Construct the boundary case deliberately &mdash; it is the only test that distinguishes &ldquo;correct&rdquo; from &ldquo;correct on this data&rdquo;.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>A verifier that trusts a producer's conclusions while still checking them is a distinctive arrangement, and the collection has three other examples of the same shape at different levels of trust. <a href="/courses/pe/lessons/pe-load-config">A PE load config</a> records the security cookie size and the guard flags, and the loader checks them. <a href="/courses/elf/lessons/section-header-table">An ELF <code>sh_flags</code></a> records what a section is, and the loader believes it. <strong>The difference here is that the checked claim is about the code in the same file, which makes the arrangement unusually strong: a producer cannot lie, because the verifier re-derives the claim by simulating the code and comparing.</strong> The load config is trusted on the producer's word; the stack map is checked against the very bytes it describes.</p>
                <p>The delta encoding is the same technique as <a href="/courses/dwarf/lessons/dwarf-loclists">a DWARF <code>.debug_loc</code> list</a> and the same as <a href="/courses/coff/lessons/coff-symbol-table">a COFF line-number run</a>: store what changed, not the state. All three exist because the states are highly repetitive and a consumer already holds the previous one. <strong>DWARF is the closest in spirit, because a location list also answers &ldquo;where does this type apply&rdquo; and also encodes a transition rather than a snapshot</strong> &mdash; and a DWARF consumer that ignored the deltas would report the wrong variable type at exactly the points where a variable changes, which is where anyone debugging cares.</p>
                <p>The <code>TOP</code> tag is the strongest thread back to the constant pool. This course has now found the same 64-bit rule in three separate places: <strong>two pool indices, two local slots, two stack slots, and a <code>TOP</code> verification type for the unusable half</strong>. The first was a <a href="/courses/jvm/lessons/jvm-constant-pool">fetch-uniformity</a> decision and the second a <a href="/courses/jvm/lessons/jvm-members">frame-sizing</a> one, but the third is the clearest statement of the underlying reason: <strong>the type system itself models the gap</strong>. A verifier that tracks a <code>long</code> has to have a name for the slot the value does not occupy, and rather than leaving it implicit the format gives it a tag and writes it in the file. That is a format choosing to make its own internal bookkeeping explicit, and it is the same instinct as the <a href="/courses/jvm/lessons/jvm-strings">two-byte NUL</a>: represent the awkward case rather than hope tools handle it.</p>
                <p>And the honest limit of this module belongs here, because it is where the difficulty is. A <code>StackMapTable</code> is a <em>proof sketch</em> the verifier checks rather than a proof it derives, and the whole design rests on the compiler having done the analysis. <strong>Any class file writer is a type checker whether it admits it or not</strong>, which is a real barrier to entry for a format that is otherwise remarkably easy to read. Every format with a verifier has some version of this &mdash; <a href="/courses/pe/lessons/pe-load-config">control flow guard</a> requires a linker to compute a bitmap &mdash; but the JVM is the case where the requirement is unavoidable, because the verifier's speed depends on it.</p>
                <p>That completes Module 2. Every part of a class file outside the constant pool has now been covered: the members and their types, the frame declaration, the instruction encoding, the offsets, and the verifier's own conclusions. What is left in the format is <a href="/courses/jvm/lessons/jvm-intro">a long list of attributes</a> &mdash; <code>InnerClasses</code> and the <code>$1</code> numbering, <code>Signature</code> for generics, annotations, records, sealed classes, and modules &mdash; and the question of how a format that has no section table accommodates twenty years of new features. <a href="/courses/jvm/lessons/jvm-header">Back to the start</a> for the whole shape.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-branches">Previous: Two Offset Conventions</a></span>
                <span><a href="/courses/jvm/lessons/jvm-intro">Back to the start of the course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
