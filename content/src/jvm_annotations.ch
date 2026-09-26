// JVM Course — Module 3: The Attribute Mechanism
// Concept: annotations — character-literal type tags, and why every annotation
// constant is a constant pool index.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_jvm_annotations() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Annotations — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson jvm-lesson">
            <a href="/courses/jvm" class="back-link">Back to course</a>
            <h1>Annotations</h1>
            <div class="lesson-meta">20 min &middot; Module 3: The Attribute Mechanism &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>An annotation is metadata attached to a declaration and read by reflection. The interesting question is not what that means but <strong>how a container format encodes a value whose type is itself a name</strong>, because that is a recursion the format has to break somewhere.</p>
                <p>It breaks it in the most economical way available. An annotation value can be a primitive, a <code>String</code>, an enum constant, a class literal, another annotation, or an array of any of those &mdash; and <strong>the encoding of the value is always a constant pool index</strong>, never an inline value. So <code>@Marker(num = 2)</code> does not put the bytes for <code>2</code> in the attribute; it puts an index to a <code>CONSTANT_Integer</code> that holds <code>2</code>, and that entry is shared with every other use of <code>2</code> in the file.</p>
                <p>And the type tag that says which kind it is <strong>is the character itself</strong>. <code>0x49</code> is <code>I</code> for int, <code>0x73</code> is <code>s</code> for String, <code>0x5A</code> is <code>Z</code> for boolean. A number would have done; a character is what a human reading a hex dump actually wants, and it is the one place in the format where the encoding is chosen for legibility over compactness.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The attribute's body, and the shape of a value inside it:</p>
                <div class="formula">
RuntimeVisibleAnnotations:
    u2 number_of_annotations
    then that many:
        u2 type_index              a Utf8: the annotation's DESCRIPTOR,
                                   e.g. "LMarker;"  -- note the L and ;
        u2 number_of_element_value_pairs
        then that many:
            u2 element_name_index   a Utf8: the member's name
            element_value value

element_value:
    u1 tag                       THE CHARACTER -- see below
    u2 const_value_index         ALWAYS a constant pool index
</div>
                <p><strong>That last line is the whole concept.</strong> The tag says how to <em>interpret</em> the pool entry the index points at, and every value is a reference. The types and their tags:</p>
                <div class="hex-dump">
                    <pre>  tag  char  type            points at
    0x42  B     byte             CONSTANT_Integer
    0x43  C     char             CONSTANT_Integer
    0x44  D     double           CONSTANT_Double
    0x46  F     float            CONSTANT_Float
    0x49  I     int              CONSTANT_Integer
    0x4A  J     long             CONSTANT_Long
    0x53  S     short            CONSTANT_Integer
    0x5A  Z     boolean          CONSTANT_Integer
    0x73  s     String           CONSTANT_Utf8
    0x65  e     enum             CONSTANT_Utf8 -- "EnumType.fieldName"
    0x63  c     class            CONSTANT_Utf8 -- a descriptor
    0x40  @     annotation       a nested annotation, inline
</pre>
                </div>
                <p>Three things fall out of that table, and each is a trap.</p>
                <p><strong>The primitives share three pool tags.</strong> <code>byte</code>, <code>char</code>, <code>short</code>, <code>int</code> and <code>boolean</code> are all <code>CONSTANT_Integer</code> &mdash; the tag byte is the only thing distinguishing them, and it is a byte that was kept purely so a hex dump is readable. <strong>The pool entry cannot tell you which of the five it is.</strong></p>
                <p><strong><code>s</code> is lowercase and <code>S</code> is uppercase.</strong> That is the single case-difference in the whole format, it is one bit, and it is the difference between <code>String</code> and <code>short</code>. A reader that uppercases its tags, or that compares them case-insensitively, will mis-read a string value as a short and then misinterpret the following bytes.</p>
                <p>And <strong>an enum constant is a <code>CONSTANT_Utf8</code> holding <code>"EnumType.fieldName"</code></strong> &mdash; a dotted pair in one string, not a class reference and a name index. <strong>A class literal is a <code>CONSTANT_Utf8</code> holding a descriptor</strong>, so <code>Foo.class</code> is the string <code>"LFoo;"</code> and not a <code>CONSTANT_Class</code> index. Both are a deliberate flattening: an enum value and a class value have no <em>identity</em> to the verifier, so they get no pool entry of their own.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>A complete annotation, all eleven bytes of it, from the class-level <code>@Marker("hello")</code>:</p>
                <div class="hex-dump">
                    <pre>  00 01        ONE annotation

  00 0e        type_index = 14, and entry 14 is
               the Utf8 "LMarker;"     &lt;- a DESCRIPTOR, not a Class

  00 01        ONE element-value pair

  00 0f        name_index = 15, and entry 15 is
               the Utf8 "value"

  73           tag 0x73 = 's' = String

  00 16        const_value_index = 22, and entry 22 is
               the Utf8 "hello"

  total: 11 bytes, and the value "hello" is stored in the POOL,
  not in the attribute.
</pre>
                </div>
                <p>Now two annotations with two pairs each and three different value types, to see the machinery repeat:</p>
                <div class="hex-dump">
                    <pre>  00 02 00 0e 00 02 00 0f 73 00 10 00 11 49 00 12
  |  |  |     |     |     |  |     |  |  |
  |  |  |     |     |     |  |     |  |  +-- #18 = Integer 2
  |  |  |     |     |     |  |     |  +----- #17 = "num", tag 'I' = int
  |  |  |     |     |     |  |     +-------- #16 = Utf8 "m"
  |  |  |     |     |     |  +-------------- tag 's' = String
  |  |  |     |     |     +----------------- #15 = "value"
  |  |  |     |     +----------------------- 2 pairs
  |  |  |     +----------------------------- #14 = "LMarker;"
  |  |  +--------------------------------------- 2 annotations
  |  +-------------------------------------------- ONE annotation
  +------------------------------------------------ TWO annotations

  00 13 00 00
  #19 = "Ljava/lang/Deprecated;" with ZERO pairs
</pre>
                </div>
                <p>And the parser output, which agrees with the bytes:</p>
                <div class="hex-dump">
                    <pre>  method go: 20 bytes
    [0] type = LMarker;
            value   tag=0x73 's' = String  -> #16
            num     tag=0x49 'I' = int     -> #18
    [1] type = Ljava/lang/Deprecated;
            zero pairs
    consumed 20 of 20   OK
</pre>
                </div>
                <p><strong>Twenty bytes, and not one of them is a value.</strong> Four pool indices carry the four pieces of information and the rest is shape. That is the encoding's whole character, and it is the same economy the constant pool provides everywhere else &mdash; a name used twice is stored once.</p>
                <h3>The mistake this course made, and what it cost</h3>
                <p>Decoding that middle pair, the first analysis assumed the <code>int</code> payload was <strong>four bytes inline</strong> and read <code>00 12 00 13</code> as the value 1179667. The source said <code>num = 2</code>.</p>
                <p>The way that was caught is worth recording, because the arithmetic did not merely look wrong &mdash; it did not close. Eleven bytes of attribute plus ten more had to account for exactly twenty, and a four-byte payload left two bytes over, which then had to be the start of the next annotation. It was not, because <code>type_index = 0</code> is the reserved constant pool entry and no valid annotation can name it. <strong>A parse that does not balance is a parse that is wrong, and the imbalance is louder evidence than a surprising number.</strong></p>
                <div class="callout callout-warn">
                    <strong>The rule is a uniform two-byte payload, and the reason is arithmetic rather than tradition.</strong> Every value is a pool index, so <code>int</code> costs two bytes pointing at an eight-or-four-byte entry rather than four bytes inline &mdash; and <code>long</code> costs two bytes pointing at a <em>two-slot</em> entry rather than eight inline, where the two-slot rule from <a href="/courses/jvm/lessons/jvm-constant-pool">the constant pool</a> would have cost nine with padding. <strong>A uniform <code>u2</code> is never larger than any inline encoding and is sometimes half the size</strong>, and it comes with deduplication for free. That is the whole argument, and it is the same one that put the constant pool at the centre of the format.
                </div>
                <h3>Why there are two annotation attributes</h3>
                <p>A class carries <code>RuntimeVisibleAnnotations</code> and <code>RuntimeInvisibleAnnotations</code>, and the distinction is a retention policy &mdash; <code>@Retention(RetentionPolicy.CLASS)</code> versus <code>RUNTIME</code> &mdash; enforced by the compiler choosing which attribute to emit. <strong>Both are in the file; only one is read by reflection.</strong></p>
                <p>So <code>RetentionPolicy.SOURCE</code> annotations are not in the class file at all, <code>CLASS</code> ones are in a file no runtime API will show you, and <code>RUNTIME</code> ones are in the attribute reflection reads. <strong>Three policies, two attributes, and one of them is the absence of the annotation</strong> &mdash; which is the only case in the whole format where the way to store a declaration is not to store it.</p>
                <p>And the class-level example shows the naming convention for the whole family: <code>RuntimeVisibleAnnotations</code>, <code>RuntimeInvisibleAnnotations</code>, <code>RuntimeVisibleParameterAnnotations</code>, <code>RuntimeVisibleTypeAnnotations</code>, and the <code>Invisible</code> and <code>Type</code> variants of each. <strong>Four orthogonal axes &mdash; visibility, parameter versus declaration, type versus declaration, and a <code>Repeatable</code> container</strong> &mdash; multiplied out into a dozen attribute names, all identical in body shape. It is a small illustration of a cost the escape hatch does not avoid: a new axis would mean a new attribute name, not a new structure.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why the encoding puts everything in the pool, told through the two things that break when it does not. Both are from tools that exist and both are silent.</p>
                <div class="formula">
  PROBLEM 1: arrays and nested annotations have no pool tag

  @Anno with ints = an array 1, 2, 3   what is the tag?

    There isn't one. The specification says a value with tag
    '[' is... not in the list. Arrays are encoded as the ANNOTATION
    COUNT mechanism: an annotation with n values has n+1 pairs,
    where the LAST pair has an empty name and the array's values.

  @Anno(nested = @Inner("x"))     the tag is '@' and the value is a
                                   WHOLE NESTED ANNOTATION, inline,
                                   recursively. No pool entry.

  so two of the eight value kinds are NOT pool references, and a
  reader that assumed every value is a u2 index will mis-parse both.
</div>
                <p><strong>That is the real complication, and it is worth being precise about.</strong> Six of the eight kinds are a one-byte tag and a <code>u2</code> index. The array form reuses the pair list with an empty name, and the annotation form embeds a whole annotation recursively. So <code>element_value</code> is not a fixed-size record, and a reader cannot walk an annotation attribute without branching on the tag &mdash; which is the first genuinely variable-length structure inside an attribute body in this format.</p>
                <p>And the second problem is the one a rewriter hits. <strong>Because every value is a pool index, renaming anything means rewriting the pool, not the attribute.</strong> A tool that renames a class from <code>Foo</code> to <code>Bar</code> must update the <code>CONSTANT_Class</code> entry, the <code>CONSTANT_Utf8</code> for its name, every descriptor mentioning it, and every signature &mdash; and if an annotation holds a class literal, the value is a <code>CONSTANT_Utf8</code> holding a descriptor string, which is <em>not</em> reachable by following the <code>CONSTANT_Class</code> index. <strong>It is a string that looks like a name, in a pool entry that nothing else points at.</strong></p>
                <p>Compare a format where a class reference is always a reference: in <a href="/courses/coff/lessons/coff-relocations">a COFF relocation</a> the target is a symbol index, and a rewriter follows it. Here, a class literal in an annotation is a <em>string</em> that must be parsed to discover it names a class, and a rewriter that only follows indices will miss it entirely. <strong>Flattening a type into a string buys uniformity for the value encoding and costs the ability to find it by reference</strong> &mdash; and that is a genuine trade, not a free win, and it is the same trade as the <a href="/courses/jvm/lessons/jvm-header">signature's inline type arguments</a> making.</p>
                <p>One last thing about the tag bytes, because it is the sort of detail that separates a reader from a decoder. <strong>They are the ASCII codes of the type's first letter, case-sensitive, with one exception that is not a letter at all</strong>: <code>@</code> for an annotation, which is 0x40 and is a symbol rather than a character. So nine of ten tags are letters, the tenth is punctuation, and <code>s</code> is lowercase among eight uppercase ones. A tool that wants to print a tag should map it through a table rather than transform it, because <code>chr(0x73)</code> is already the right answer and any case-folding breaks it.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ javap -v -p out/Anno.class
$ python3 courses/jvm/assets/samples/crosscheck.py classes/Anno.class</code></pre>
                <ul>
                    <li><strong>Decode the eleven-byte annotation by hand before reading anything.</strong> Six shape bytes and four indices, and the string is not among them. <strong>Doing that once makes the "everything is a pool index" idea permanent.</strong></li>
                    <li><strong>Write the tag table and test all ten.</strong> An annotation with every value kind the language allows, compiled and dumped. <strong>Then uppercase your table and watch the <code>String</code> value become a <code>short</code></strong> &mdash; and note that the parse still balances, because both are two-byte payloads. That is the most dangerous property of this bug.</li>
                    <li><strong>Find the two non-pool value kinds.</strong> An annotation with an array value and one with a nested annotation. <strong>The array reuses the pair list with an empty name, and the nested one is inline and recursive</strong> &mdash; and those two are why <code>element_value</code> is not fixed-size.</li>
                    <li><strong>Prove the deduplication.</strong> An annotation with <code>num = 2</code>, and a separate <code>static final int TWO = 2</code>. <strong>One <code>CONSTANT_Integer</code> in the pool, referenced twice</strong> &mdash; and that is the whole reason the values are indexed.</li>
                    <li><strong>Compare the retention attributes.</strong> The same annotation under <code>RetentionPolicy.SOURCE</code>, <code>CLASS</code> and <code>RUNTIME</code>. <strong>Two of the three produce no <code>RuntimeVisibleAnnotations</code> attribute at all</strong>, and that absence is the encoding for a source-only declaration.</li>
                    <li><strong>Break a rewriter on a class literal.</strong> Take a tool that renames a class by following pool indices, and point it at a field annotated <code>@Some(Foo.class)</code>. <strong>It will miss the class literal, because that value is a Utf8 descriptor string rather than a Class index</strong> &mdash; and the class will load with a stale name in its annotation.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an annotation's element-value pair for <code>num</code> has the name <code>"num"</code>, the tag byte <code>0x49</code>, and the bytes <code>00 12</code>. The source says <code>num = 2</code>. What is the tag, what is <code>#18</code>, and how many bytes of the attribute does the value <code>2</code> itself occupy?</p>
                <div class="quiz" id="quiz-jvm-annotations-1">
                    <button class="quiz-option" data-correct="true" data-explain="Three things, and the third is the one that catches people. The tag 0x49 is the ASCII code for I, which is how the format says int, and it is a character rather than a number so that a hex dump is legible. Entry 18 is a CONSTANT_Integer holding 2, and it is shared with every other use of the value 2 in the file. The value occupies zero bytes of the attribute: the two bytes 00 12 are the index, and the value itself is in the pool. That is the whole design, and it is why the payload is uniformly two bytes -- because an index is never larger than an inline value and is sometimes half the size, since a long costs two bytes here rather than eight inline plus the padding a two-slot pool entry would need. It is also what caught this course's own decoder, which assumed a four-byte inline int and read a value of 1179667 from bytes that were actually an index and half of the next annotation. The parse did not balance, and the imbalance was the evidence." onclick="checkQuiz('quiz-jvm-annotations-1', this)">The tag is <code>'I'</code> for int, <code>#18</code> is a <code>CONSTANT_Integer</code> holding 2, and the value occupies <strong>zero</strong> bytes of the attribute &mdash; the two bytes are the index. Every annotation value is a pool reference, which is why the payload is uniformly a <code>u2</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="The tag is right but the storage claim is the exact mistake this concept was written to correct, and it is worth seeing why it feels plausible: the specification's own tables for other formats put a value inline, and a four-byte int is the obvious size for an int. What gives it away is the arithmetic. Eleven bytes of attribute plus ten for a second annotation has to come to exactly twenty, and a four-byte payload leaves two bytes over, which would have to be the next annotation's type_index of zero -- and index zero is the reserved constant pool entry that no valid annotation can name. A parse that does not balance is a parse that is wrong, and here the imbalance was louder than the surprising number. The uniform two-byte payload is also the better design on arithmetic grounds alone, independent of the deduplication." onclick="checkQuiz('quiz-jvm-annotations-1', this)">The tag is <code>'I'</code> for int, <code>#18</code> holds the value inline, and the int occupies four bytes of the attribute immediately after the tag</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a tool that reads annotations. On one class it reports <code>@Marker(value="m", num=0)</code> where the source says <code>num=2</code>, and it consumes exactly the right number of bytes. On a second class it desynchronises and reports nonsense for every annotation after the first. The first class has <code>@Marker(value="m")</code> and a deprecated method; the second has <code>@Marker(num=2)</code> and an array-valued annotation. What are the two defects, and what is the general habit for parsing a value whose type is a tag byte?</p>
                <div class="quiz" id="quiz-jvm-annotations-2">
                    <button class="quiz-option" data-correct="true" data-explain="Two distinct defects with two distinct signatures, and the fact that the first consumes the right number of bytes is the clue that separates them. In the first case the tool read the tag correctly and the index correctly but resolved the index to the wrong thing, or printed the pool entry's own value rather than interpreting it by the tag: byte, char, short, int and boolean are all CONSTANT_Integer, so the tag is the only thing that says which of the five it is, and a tool that resolves the index and prints the integer has thrown away the one piece of information that mattered. It consumes the right bytes because the layout was right and only the interpretation was wrong, which is the most dangerous possible combination. In the second case the tool desynchronises, and the array value is the cause: arrays are not a pool reference at all, they reuse the annotation's own pair list with an empty name for the final element, so a reader that assumes every element_value is one tag byte plus two bytes will consume two bytes where the array needs none and walk into the rest of the attribute. The general habit is that a tag byte is a type discriminator and everything after it depends on it, so a parser must branch on the tag and have a path for every legal value -- including the ones that are not fixed-size, which here are the array and the nested annotation. And a value that is a single index is a value to be resolved through the tag, not printed." onclick="checkQuiz('quiz-jvm-annotations-2', this)">The first is a tag-interpretation error &mdash; five types share <code>CONSTANT_Integer</code> and only the tag distinguishes them, and consuming the right bytes proves the layout was fine. The second is the array form, which is not a pool reference at all but reuses the pair list with an empty name, so a fixed two-byte-per-value assumption desynchronises. Branch on the tag, and handle the two non-fixed-size kinds</button>
                    <button class="quiz-option" data-correct="false" data-explain="The first failure's signature rules this out. If the tool were not resolving the index and were printing the tag's character instead of a value, it would print I rather than 0, and it would do so on every int-valued annotation rather than only where the source disagrees. More decisively, the report says the wrong value is 0 and the source says 2, which means a number was produced -- and the only numbers available are the index and the pool entry's value. The index is 18, which is not what was printed, so the tool did resolve it and got the right entry. The failure is in what it did with the entry after resolving it, which is a question about the tag, not about whether to resolve. The desynchronisation on the second class is a separate and different bug about variable-length values." onclick="checkQuiz('quiz-jvm-annotations-2', this)">Both are the same defect: the tool is not resolving the constant value index through the tag, and printing the index itself rather than the pool entry it points at</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a tag byte is a type discriminator and everything after it depends on it. Resolve the tag first, then the payload &mdash; and when a value can be variable-length, check that the parse balances before trusting any of the values you read.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Annotations are the format's most conventional corner, and the comparisons are instructive precisely because everything else about them is unremarkable. <a href="/courses/dwarf/lessons/dwarf-standard-opcodes">A DWARF attribute</a> is a tag, a form, and a value &mdash; the same three-part shape &mdash; and DWARF's <code>DW_FORM</code> is a genuine enumerated tag byte rather than a character. <strong>DWARF chose numbers because it was specified for machines to read and for people to write generators</strong>, and the JVM chose characters because a class file is overwhelmingly read with a hex dump. Neither is better; the choice tracks who the reader is.</p>
                <p>The more interesting comparison is what a DWARF attribute value can be. <code>DW_FORM_ref_addr</code>, <code>DW_FORM_strx</code> and <code>DW_FORM_addrx</code> are all <em>indirect</em> forms that point at a string, a line table or the address table rather than carrying the value &mdash; <strong>exactly the choice the annotation encoding makes, for exactly the reason: the value is bigger than the form, or it is shared, or both.</strong> And DWARF went further, adding <em>implicit</em> forms where the value is computed from the object's address and appears nowhere in the file, which is a step further in the same direction and a good illustration of how far the trend goes once a format commits to referencing rather than embedding.</p>
                <p>The pooling choice also lands where the rest of this course has been going. A <a href="/courses/pe/lessons/pe-load-config">PE load config's</a> cookie fields are inline because they are small, unique, and fixed; a <a href="/courses/elf/lessons/relocation-entries">COFF symbol's</a> name is an offset into a string table because names are neither small nor unique. <strong>Annotation values are small but not unique</strong> &mdash; <code>num = 2</code> appears in thousands of annotations &mdash; and that is the case a string table exists to serve. The format picked the table because the reuse was the dominant consideration, and picked it uniformly, so that a reader needs one rule rather than one per value type.</p>
                <p>The trade that uniformity costs is worth keeping in view, because it is the same trade the <a href="/courses/jvm/lessons/jvm-signatures">signature grammar</a> makes. <strong>Inline a value and it becomes findable by position; reference it and it becomes shared but only reachable by an index.</strong> A class literal in an annotation is the case that bites: it is the string <code>"LFoo;"</code> in a pool entry nothing else points at, so a rewriter following indices misses it. The same flattening in the signature grammar means a repeated type argument is written out twice rather than shared. <strong>Both are grammars that buy a uniform, simple structure by giving up reachability</strong>, and both are reasonable, and a tool that walks a class file by reference rather than by parsing has to know which of the two it is looking at.</p>
                <p>That closes Module 3. The mechanism, the names, the type information and the metadata are all attributes now &mdash; which is the point of the module, and the reason the format needed no new layout in twenty years. <a href="/courses/jvm/lessons/jvm-records">Module 4</a> takes the three shapes the language has added most recently, and they are the three that have needed the most from the mechanism: a record component that carries its own attributes, a permitted subclass that is a bare list of indices, and an enum that is a class shape the language has to synthesise wholesale.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/jvm/lessons/jvm-signatures">Previous: The Signature Attribute</a></span>
                <span><a href="/courses/jvm/lessons/jvm-records">Next: Records</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
