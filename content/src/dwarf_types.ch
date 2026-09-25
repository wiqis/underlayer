// DWARF Course — Module 3: DIEs, Types, Scopes, Locations and Frames
// Concept: DW_AT_type chains, and the inclusive upper bound.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_types() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Types and Type Chains — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Types and Type Chains</h1>
            <div class="lesson-meta">22 min &middot; Module 3: DIEs, Types and Scopes &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Ask a debugger to print <code>g_nest.next-&gt;x</code> and it has to answer four questions in order: what type is <code>g_nest</code>, where in it does <code>next</code> live, what type is that, and where in <em>that</em> does <code>x</code> live. DWARF stores none of that as a single answer. It stores a graph of type DIEs joined by one attribute, and the reader walks it.</p>
                <p>This is the last genuinely hard idea in the format. Once you can follow a <code>DW_AT_type</code> chain, everything a debugger prints is just this walk repeated with different starting points.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Each type is one DIE. Composition is a reference: <code>DW_AT_type</code> holds the <code>.debug_info</code> offset of another DIE, and following it is a pointer chase in a file with no addresses.</p>
                <p>Five shapes cover almost everything:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Tag</th><th scope="col">Means</th><th scope="col">Children / attributes that matter</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>DW_TAG_base_type</code></td><td>a leaf: int, char, double</td><td><code>DW_AT_byte_size</code>, <code>DW_AT_encoding</code>, <code>DW_AT_name</code></td></tr>
                        <tr><td><code>DW_TAG_typedef</code></td><td>an alias, not a new type</td><td><code>DW_AT_type</code> &rarr; the real type</td></tr>
                        <tr><td><code>DW_TAG_pointer_type</code></td><td>a pointer</td><td><code>DW_AT_byte_size</code>, <code>DW_AT_type</code> &rarr; the pointee (optional &mdash; <code>void*</code> has none)</td></tr>
                        <tr><td><code>DW_TAG_structure_type</code></td><td>a struct or union</td><td><code>DW_AT_byte_size</code>, one <code>DW_TAG_member</code> child per field</td></tr>
                        <tr><td><code>DW_TAG_array_type</code></td><td>an array</td><td><code>DW_AT_type</code> &rarr; element type, one <code>DW_TAG_subrange_type</code> child for the bounds</td></tr>
                    </tbody>
                </table>
                <p>And the members carry the offsets that make the whole thing work:</p>
                <ul>
                    <li><code>DW_TAG_member</code> with <code>DW_AT_data_member_location</code> &mdash; the byte offset from the <em>start</em> of the struct.</li>
                    <li><code>DW_TAG_subrange_type</code> with <code>DW_AT_upper_bound</code> &mdash; and here is the trap this concept exists for.</li>
                </ul>
                <div class="callout callout-warn">
                    <strong>A typedef is a hop, not a shortcut.</strong> <code>uint32_t</code> in this file is a <code>DW_TAG_typedef</code> whose <code>DW_AT_type</code> points at another typedef, which points at the real <code>unsigned int</code>. Following <code>DW_AT_type</code> once does not give you the answer; you keep going until you reach a DIE with no <code>DW_AT_type</code>. Any tool that shows you <code>uint32_t</code> as the type of a variable is stopping early, which is a legitimate display choice but not a complete one.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The source being described, so every number below has a source you can point at:</p>
                <pre><code>struct Point &#123; int x; int y; &#125;;

struct Nest &#123;
    struct Point origin;
    char        label[8];
    uint32_t    flags;
    struct Point *next;
&#125;;</code></pre>
                <p>Here is the complete type graph, exactly as the reference binary records it. Offsets are <code>.debug_info</code>-relative and were confirmed against <code>readelf</code> and <code>llvm-dwarfdump</code>.</p>
                <div class="hex-dump">
                    <pre>&lt;0x5d&gt; base_type  int                 byte_size 4
&lt;0x41&gt; base_type  unsigned int         byte_size 4
&lt;0x48&gt; base_type  long unsigned int    byte_size 8
&lt;0x77&gt; base_type  char                 byte_size 1

&lt;0x64&gt; typedef __uint32_t  -&gt; &lt;0x41&gt;
&lt;0x7e&gt; typedef uint32_t     -&gt; &lt;0x64&gt;
&lt;0x8a&gt; typedef ulong_t      -&gt; &lt;0x48&gt;

&lt;0x96&gt; structure_type Point   byte_size 8
  &lt;0xa1&gt; member x  -&gt; &lt;0x5d&gt; int    data_member_location 0
  &lt;0xaa&gt; member y  -&gt; &lt;0x5d&gt; int    data_member_location 4

&lt;0xb4&gt; structure_type Nest    byte_size 32
  &lt;0xbf&gt; member origin -&gt; &lt;0x96&gt; Point   offset  0
  &lt;0xcb&gt; member label  -&gt; &lt;0xf0&gt; array   offset  8
  &lt;0xd7&gt; member flags  -&gt; &lt;0x7e&gt; uint32_t offset 16
  &lt;0xe3&gt; member next   -&gt; &lt;0x100&gt; pointer offset 24

&lt;0xf0&gt; array_type  -&gt; &lt;0x77&gt; char
  &lt;0xf9&gt; subrange_type -&gt; &lt;0x48&gt; upper_bound 7

&lt;0x100&gt; pointer_type  byte_size 8  -&gt; &lt;0x96&gt; Point</pre>
                </div>
                <p>Three verifications that this is a real type graph and not a plausible-looking invention:</p>
                <ol>
                    <li><strong>The struct size is the sum of its members, rounded up.</strong> <code>Point</code> is 8: two 4-byte ints at 0 and 4. <code>Nest</code> is 32: a <code>Point</code> at 0 (8 bytes), <code>char[8]</code> at 8 (8 bytes), <code>uint32_t</code> at 16 (4 bytes), then a pointer at 24 &mdash; not 20, because a 4-byte field followed by an 8-byte field must be padded to keep the pointer 8-byte aligned. <strong>The padding is inferred from the offsets, and it is not recorded anywhere.</strong> The gap between 20 and 24 exists in the struct and has no DIE.</li>
                    <li><strong>The chain terminates in a base type.</strong> <code>flags</code> is <code>uint32_t</code>, which is a typedef, which points at <code>__uint32_t</code>, which is another typedef, which points at <code>unsigned int</code> &mdash; a <code>DW_TAG_base_type</code> with no <code>DW_AT_type</code>. Three hops from a field to its four bytes.</li>
                    <li><strong>Every reference is an offset into the same section.</strong> <code>&lt;0x100&gt;</code> is not an address; it is a byte offset in <code>.debug_info</code>. Reading it as a virtual address finds nothing, and on a PIE binary it finds nothing that looks plausible either.</li>
                </ol>
                <h3>The inclusive bound</h3>
                <p><code>label</code> is declared <code>char label[8]</code>. The array DIE's child says:</p>
                <div class="formula">
&lt;2&gt;&lt;f9&gt;  DW_TAG_subrange_type
        DW_AT_type        &lt;0x48&gt;   (long unsigned int &mdash; the index type)
        DW_AT_upper_bound : 7
                </div>
                <p><strong>Seven, not eight.</strong> <code>DW_AT_upper_bound</code> is an <em>inclusive</em> bound: valid indices run 0 to 7, so the element count is <code>upper_bound + 1</code>. This is a genuinely expensive mistake, because a pretty-printer that uses the value directly prints seven characters of an eight-character field and there is nothing anywhere that says the loop is wrong. The value is in range, the type is valid, and the output looks fine.</p>
                <p>Two related things sit next to it. The index type is a <em>separate</em> type &mdash; <code>DW_AT_type</code> on the <code>DW_TAG_subrange_type</code> points at <code>long unsigned int</code>, not at <code>int</code> &mdash; because array indexing in C promotes to a large type, and a debugger that has to compute a byte offset needs the promoted width. And the <code>subrange_type</code> is a <em>child</em> of the array, not an attribute, which is what allows multidimensional arrays: each dimension is one child.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Take one expression and walk it by hand, using only the table above. The question is: what does <code>g_nest.next-&gt;x</code> mean, byte by byte?</p>
                <ol>
                    <li><code>g_nest</code> is a <code>DW_TAG_variable</code> whose <code>DW_AT_type</code> is <code>&lt;0xb4&gt;</code> &mdash; <code>Nest</code>.</li>
                    <li>Look up <code>next</code> among <code>Nest</code>'s members. Found at <code>&lt;0xe3&gt;</code> with <code>DW_AT_data_member_location : 24</code>. So the field is 24 bytes into the struct.</li>
                    <li>That member's <code>DW_AT_type</code> is <code>&lt;0x100&gt;</code> &mdash; a <code>DW_TAG_pointer_type</code>. So the field holds an <em>address</em>, not a struct. Adding 24 to the address of <code>g_nest</code> gives the address of the pointer.</li>
                    <li>The pointer's <code>DW_AT_type</code> is <code>&lt;0x96&gt;</code> &mdash; <code>Point</code>. Dereferencing follows this reference. The value read from those 8 bytes is the address of a <code>Point</code>, or zero.</li>
                    <li>Now inside <code>Point</code>: member <code>x</code> at <code>&lt;0xa1&gt;</code> with <code>DW_AT_data_member_location : 0</code>, and its <code>DW_AT_type</code> is <code>&lt;0x5d&gt;</code> &mdash; <code>int</code>, a base type with no further <code>DW_AT_type</code>.</li>
                    <li>The walk stops. Read 4 bytes at offset 0 of the <code>Point</code> and interpret them as a signed 32-bit integer.</li>
                </ol>
                <p>Six steps, four <code>DW_AT_type</code> references and two <code>data_member_location</code> values. That is the whole of <code>g_nest.next-&gt;x</code>. Now the same walk for <code>g_nest.label[3]</code>:</p>
                <ol>
                    <li><code>label</code> is at offset 8, and its type is <code>&lt;0xf0&gt;</code>, an array.</li>
                    <li>The array's <code>DW_AT_type</code> is <code>&lt;0x77&gt;</code> &mdash; <code>char</code>, one byte.</li>
                    <li>The bound is <code>upper_bound = 7</code>, so 3 is in range. Index 3 is at 8 + 3 = offset 11.</li>
                    <li>Read one byte at offset 11 and print it as a character.</li>
                </ol>
                <div class="callout callout-tip">
                    <strong>The rule the whole format rests on.</strong> A variable is an address plus a type. A type is either a value (a base type) or a recipe for reaching a value (pointer, array, struct, union). Following the recipe is what a debugger does, and it is the same handful of steps every time. If you can walk <code>g_nest.next-&gt;x</code> on paper, you can read any type graph.
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ readelf --debug-dump=info shape | grep -E 'DW_TAG_(structure|member|array|subrange|pointer|typedef|base_type)|DW_AT_(type|data_member_location|upper_bound|byte_size)'</code></pre>
                <p>Then the exercise that turns the table above into understanding:</p>
                <ul>
                    <li><strong>Add a fifth member</strong> &mdash; say <code>double scale;</code> &mdash; to <code>struct Nest</code>, recompile, and diff the member list. The new member's <code>data_member_location</code> tells you where the compiler chose to put it, and the answer is not always the end.</li>
                    <li><strong>Reorder the members</strong> so the <code>double</code> comes first. The <code>byte_size</code> of the struct usually does not change, but every <code>data_member_location</code> does. The layout is the compiler's decision; DWARF only records it.</li>
                    <li><strong>Count the hops.</strong> Change <code>flags</code> from <code>uint32_t</code> to plain <code>unsigned</code> and watch the two typedef DIEs disappear from the tree entirely. The struct's size and the field's offset do not change &mdash; the graph gets shorter, and the bytes are identical.</li>
                    <li><strong>Break the bound deliberately.</strong> Change <code>label[8]</code> to <code>label[9]</code> and confirm <code>DW_AT_upper_bound</code> becomes 8. It tracks the source exactly, and it is always one less than the count.</li>
                </ul>
                <p>The array-bound check is the one to make a habit of. If you ever see a <code>DW_AT_upper_bound</code> equal to the element count in a <code>DW_TAG_subrange_type</code> child, something is off by one &mdash; in your reader, or in the tool that produced the file.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a <code>DW_TAG_subrange_type</code> child of an array DIE carries <code>DW_AT_upper_bound : 7</code>, and the source said <code>char label[8]</code>. How many elements does the array have, and what would a reader that used the raw value print?</p>
                <div class="quiz" id="quiz-dwarf-types-1">
                    <button class="quiz-option" data-correct="true" data-explain="DW_AT_upper_bound is an inclusive upper bound, so the valid index range is 0 to 7 and the count is 7 + 1 = 8, which matches the declaration. A reader that used the value directly would produce indices 0 to 6, printing seven elements and never reporting an error - the value is in range and the type is valid, which is exactly what makes this mistake expensive." onclick="checkQuiz('quiz-dwarf-types-1', this)">Eight elements, because the bound is inclusive and valid indices run 0 to 7. A reader using the raw value would print seven</button>
                    <button class="quiz-option" data-correct="false" data-explain="The value 7 and the count 8 are both present in the file; what differs is the convention for reading them. The correct rule is upper_bound + 1 for the count, and this answer treats the stored value as if it were already the count, which is the bug rather than the fix." onclick="checkQuiz('quiz-dwarf-types-1', this)">Seven elements, because DW_AT_upper_bound is defined as the element count and the value 7 already says so</button>
                    <button class="quiz-option" data-correct="false" data-explain="The bound comes from the declaration, not from the element type, so changing what the array holds would not change the number of elements. The index type in this file is long unsigned int because C promotes array indices, which is a separate fact from the bound and does not affect the count." onclick="checkQuiz('quiz-dwarf-types-1', this)">It depends on the element type &mdash; a char array of 8 and an int array of 8 would report different bounds</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a pretty-printer and it renders <code>g_nest</code> as <code>&#123;origin = &#123;x = 1, y = 2&#125;, label = "hi", flags = 48, next = (Nest *) 0x0&#125;</code> &mdash; which is exactly right. Then someone reports that a struct with three consecutive <code>uint8_t</code> fields prints with a gap between them. What has your reader most likely got wrong?</p>
                <div class="quiz" id="quiz-dwarf-types-2">
                    <button class="quiz-option" data-correct="true" data-explain="The layout is inferred from data_member_location, not from byte_size. Three uint8_t fields are contiguous at 0, 1 and 2, and the gap appears in the output because the reader is computing each field's position as previous_offset + previous_byte_size rather than reading the recorded offset. DWARF does not store padding and does not store field sizes for members; it stores the offsets, and they are the only authority." onclick="checkQuiz('quiz-dwarf-types-2', this)">It is deriving each field&rsquo;s offset instead of reading <code>DW_AT_data_member_location</code>. The compiler inserts padding for alignment and only the recorded offsets reveal it &mdash; a struct of three bytes followed by an 8-byte field puts that field at 8, not 3</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real DWARF subtlety, but it affects the index type of an array rather than the offsets of consecutive struct members. Member offsets are recorded directly and the reader is not inferring them from the byte sizes, which is what the reported symptom points at." onclick="checkQuiz('quiz-dwarf-types-2', this)">It is treating <code>DW_AT_upper_bound</code> as exclusive, so a three-byte field is being laid out with an extra byte between each element</button>
                    <button class="quiz-option" data-correct="false" data-explain="The byte size of a structure DIE describes the struct as a whole, not the size of its members, and it is not what positions individual fields. Mixing the two would misreport every member, not just produce a gap between adjacent single-byte fields." onclick="checkQuiz('quiz-dwarf-types-2', this)">It is reading <code>DW_AT_byte_size</code> from the structure DIE instead of from each member&rsquo;s own type, so short fields inherit the struct&rsquo;s width</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a format records derived data as a list of positions, read the positions. Never recompute a layout from the sizes &mdash; the whole purpose of recording the offsets is that the compiler, not you, knows where the padding went.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>A <code>DW_TAG_typedef</code> that points at another typedef is the same two-step indirection as a <a href="/courses/dwarf/lessons/dwarf-file-tables">line number resolving through a directory table</a>, and it exists for the same reason: the string is written once and referenced by number. DWARF's <a href="/courses/pe/lessons/pe-imports">PE course covers the import directory</a>, where a similar chain of name-thunk-table-IAT resolves a function, and the resemblance is not accidental &mdash; both formats were designed to be read by a linker or loader that must do this walk cheaply.</p>
                <p>The COFF course's <a href="/courses/coff/lessons/coff-relocations">relocation records</a> solve the related problem for code: where the answer goes depends on a layout decided later, so the compiler records the question. A <code>DW_AT_type</code> reference is the same shape of indirection applied to types instead of addresses.</p>
                <p>Types tell you what things <em>are</em>. The next concept is about where they <em>live</em> &mdash; which, for a local variable, is a stack offset that changes with every call.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-scopes">Scopes and Inlining</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-dies">Previous: The DIE Tree</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-scopes">Next: Scopes and Inlining</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
