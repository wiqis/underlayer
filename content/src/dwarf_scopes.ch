// DWARF Course — Module 3: DIEs, Types, Scopes, Locations and Frames
// Concept: lexical scope as tree nesting, and how inlining makes one function many.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_scopes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Scopes and Inlining — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Scopes and Inlining</h1>
            <div class="lesson-meta">21 min &middot; Module 3: DIEs, Types and Scopes &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A name means different things in different places. <code>x</code> inside a loop, <code>x</code> as a function parameter, and a global <code>x</code> are three unrelated variables that happen to share four characters. A debugger has to pick the right one from a program counter and nothing else &mdash; no source file, no line number, no variable name in hand.</p>
                <p>The mechanism is the simplest thing in DWARF: <strong>nesting in the DIE tree is scope</strong>. A variable DIE that is a child of a subprogram belongs to that function. One nested deeper, inside a lexical block, belongs to that block. And when the compiler inlines a function, the caller's tree grows a child that has no source-level counterpart at all &mdash; which is the second half of this concept.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three tags carry scope, and each answers a different question:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Tag</th><th scope="col">Answers</th><th scope="col">Typical attributes</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>DW_TAG_subprogram</code></td><td>which function</td><td><code>name</code>, <code>low_pc</code>, <code>high_pc</code>, <code>type</code> (the return type), <code>frame_base</code></td></tr>
                        <tr><td><code>DW_TAG_formal_parameter</code></td><td>which argument</td><td><code>name</code>, <code>type</code>, <code>location</code></td></tr>
                        <tr><td><code>DW_TAG_variable</code></td><td>which local or global</td><td><code>name</code>, <code>type</code>, <code>location</code></td></tr>
                        <tr><td><code>DW_TAG_lexical_block</code></td><td>which inner scope</td><td>usually just <code>low_pc</code>/<code>high_pc</code> or a range</td></tr>
                        <tr><td><code>DW_TAG_inlined_subroutine</code></td><td>which inlined copy</td><td><code>abstract_origin</code>, <code>call_file</code>, <code>call_line</code>, <code>low_pc</code>/<code>high_pc</code> <em>or</em> <code>ranges</code></td></tr>
                    </tbody>
                </table>
                <p>Three further points do most of the work in practice.</p>
                <p><strong>A name is not always stored.</strong> When a compiler can prove a name is obvious from context it may leave it out entirely. The parameter DIEs for <code>make_point</code> in the reference binary carry the names <code>x</code> and <code>y</code> inline, with no string-table lookup at all &mdash; <code>DW_FORM_string</code> rather than <code>strp</code>. A reader must handle both, and must not assume a name is present.</p>
                <p><strong>Globals and locals are the same tag.</strong> A <code>DW_TAG_variable</code> that is a child of the compile unit is a global; a child of a subprogram is a local. The tree position <em>is</em> the distinction, and it means <code>static</code> file-scope variables appear as compile-unit children even though they are not visible outside the file.</p>
                <div class="callout callout-warn">
                    <strong><code>abstract_origin</code> is the whole trick behind inlining.</strong> When the compiler inlines a function it needs to describe two different things: the function <em>as written</em> (its parameters, its locals, its line numbers &mdash; no addresses at all) and each place it was <em>inlined into</em> (an address range and a call site). DWARF splits them into two DIEs. The instance points back at the description with <code>DW_AT_abstract_origin</code>. Without that indirection the parameter list would be duplicated once per call site, and a debugger stepping through would see the same three parameters listed nine times.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>First, ordinary scope at <code>-O0</code>. The function <code>make_point</code> in the reference binary, at <code>.debug_info</code> offset 0x15c:</p>
                <div class="hex-dump">
                    <pre>&lt;1&gt;&lt;15c&gt;  DW_TAG_subprogram
        DW_AT_external     1            (flag_present: no bytes in .debug_info)
        DW_AT_name         make_point
        DW_AT_type         &lt;0x96&gt;      (returns struct Point)
        DW_AT_low_pc       0x11a9
        DW_AT_high_pc      0x20
        DW_AT_frame_base   1 byte block: 9c        (DW_OP_call_frame_cfa)
        DW_AT_call_all_calls 1
        DW_AT_sibling      &lt;0x1a5&gt;
  &lt;2&gt;&lt;17d&gt;  DW_TAG_formal_parameter
        DW_AT_name         x
        DW_AT_type         &lt;0x5d&gt;      (int)
        DW_AT_location     2 byte block: 91 5c    (DW_OP_fbreg -36)
  &lt;2&gt;&lt;189&gt;  DW_TAG_formal_parameter
        DW_AT_name         y
        DW_AT_type         &lt;0x5d&gt;
        DW_AT_location     2 byte block: 91 58    (DW_OP_fbreg -40)
  &lt;2&gt;&lt;195&gt;  DW_TAG_variable
        DW_AT_name         out
        DW_AT_type         &lt;0x96&gt;      (struct Point)
        DW_AT_location     2 byte block: 91 68    (DW_OP_fbreg -24)
  &lt;2&gt;&lt;1a4&gt;  00                            (closes the function)</pre>
                </div>
                <p>Three things to notice. The parameters and the local are all at depth <strong>2</strong>, children of the subprogram &mdash; there is no <code>DW_TAG_lexical_block</code> here because the function body is one scope. The names <code>x</code>, <code>y</code> and <code>out</code> are stored <em>inline</em> in two or three bytes each, not as string-table offsets. And every location is a two-byte expression, which is about as compact as a location can be.</p>
                <p>The offsets are negative and they are not in declaration order. <code>x</code> is at frame-base minus 36 and <code>y</code> at minus 40, so <code>y</code> is stored <em>lower</em> in the frame than <code>x</code>. That is not a mistake &mdash; it is the x86-64 calling convention, where arguments are pushed right to left, and it is why a location expression is a displacement from a frame base rather than a fixed address.</p>
                <h3>What inlining does to the tree</h3>
                <p>Now <code>-O2</code>, with a <code>static</code> function called from three places. <code>inline.c</code>:</p>
                <pre><code>struct Vec &#123; double x, y, z; &#125;;
static double dot(struct Vec a, struct Vec b) &#123;
    return a.x * b.x + a.y * b.y + a.z * b.z;
&#125;
double magnitude2(struct Vec v) &#123; return dot(v, v); &#125;
double work(struct Vec a, struct Vec b) &#123;
    return dot(a, b) + dot(b, a) + dot(a, a);
&#125;</code></pre>
                <p>Compiled at <code>-O2</code>, that produces <strong>three</strong> <code>DW_TAG_inlined_subroutine</code> DIEs. Two of them:</p>
                <div class="hex-dump">
                    <pre>&lt;2&gt;&lt;ea&gt;   DW_TAG_inlined_subroutine
        DW_AT_abstract_origin  &lt;0x127&gt;    (the subprogram DIE for dot)
        DW_AT_entry_pc         0x16
        DW_AT_low_pc           0x16
        DW_AT_high_pc          0x14
        DW_AT_call_file        1
        DW_AT_call_line        6
        DW_AT_call_column      12

&lt;2&gt;&lt;172&gt;  DW_TAG_inlined_subroutine
        DW_AT_abstract_origin  &lt;0x127&gt;    (the SAME subprogram DIE)
        DW_AT_entry_pc         0x52
        DW_AT_ranges           0xc          (not low_pc/high_pc!)
        DW_AT_call_file        1
        DW_AT_call_line        9
        DW_AT_call_column      12</pre>
                </div>
                <p>The pair of attributes that answers "where was this called from" is <code>DW_AT_call_file</code> plus <code>DW_AT_call_line</code> plus <code>DW_AT_call_column</code> &mdash; the call site, which for the second instance is line 9. And that instance uses <code>DW_AT_ranges</code> instead of a <code>low_pc</code>/<code>high_pc</code> pair, because the compiler did not emit the inlined body as one contiguous run of instructions. <strong>A consumer that assumes a single range will miss part of the function.</strong></p>
                <p>The <code>DW_AT_abstract_origin</code> is <code>&lt;0x127&gt;</code> in both cases: one description of <code>dot</code>, shared by all three instances. The description DIE is a <code>DW_TAG_subprogram</code> with parameters, locals and line numbers but <strong>no</strong> <code>low_pc</code> and <strong>no</strong> <code>high_pc</code> &mdash; because the function as written has no single address range. It exists three times in the machine code and nowhere in particular.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The question a debugger actually asks: <em>the program counter is at 0x1180 inside <code>work</code>. Which variables are live, and what are they?</em></p>
                <ol>
                    <li><strong>Find the subprogram containing 0x1180.</strong> Walk the compile unit's children, and for each <code>DW_TAG_subprogram</code> test whether <code>low_pc &le; pc &lt; low_pc + high_pc</code>. Remember that <code>high_pc</code> is a <em>length</em>, so the test is an addition, not a comparison. The match is <code>work</code>.</li>
                    <li><strong>Now walk the children of that subprogram.</strong> Its parameters, then its lexical blocks, then any <code>DW_TAG_inlined_subroutine</code> children. Everything at depth 2 and below is in scope.</li>
                    <li><strong>For each inlined instance, test its address range too.</strong> If 0x1180 falls inside one, then the parameters and locals of the <em>inlined</em> function are also live &mdash; and they are reached through the instance's <code>DW_AT_abstract_origin</code>, not by looking for a <code>DW_TAG_subprogram</code> named <code>dot</code>.</li>
                    <li><strong>Read each variable's <code>DW_AT_location</code> to get its address.</strong> This is where the previous concept's machinery and the next one's meet: a location is an expression, not a number.</li>
                </ol>
                <p>Step 3 is the part that is easy to skip and expensive to skip. Without it, stepping into a heavily inlined function shows you two parameters where there should be five, and the locals of the inlined body are simply absent. With it, the debugger reconstructs the source-level stack frame that the optimiser actually removed.</p>
                <div class="callout callout-tip">
                    <strong>Why the split exists at all.</strong> The description DIE and the instance DIE answer different questions and have genuinely different contents. The description knows the parameter names and types and the declaration line; it cannot know an address. The instance knows an address range and a call site; it knows nothing about the parameters, which is why it must point at the description to get them. One DIE could not carry both without either duplicating the parameter list three times or inventing an address that does not exist.
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ readelf --debug-dump=info shape | grep -A12 'DW_TAG_subprogram'
$ gcc -gdwarf-5 -O2 -c inline.c -o inline_O2.o
$ readelf --debug-dump=info inline_O2.o | grep -B2 -A9 DW_TAG_inlined_subroutine</code></pre>
                <p>Four experiments, in increasing order of how much they teach:</p>
                <ul>
                    <li><strong>Add a lexical block.</strong> Wrap the body of <code>sum_table</code> in braces and declare a variable inside. Recompile at <code>-O0</code>: a <code>DW_TAG_lexical_block</code> appears at depth 2 with the variable at depth 3, and the variable DIE now has a <code>DW_AT_ranges</code> instead of a plain location, because its lifetime is narrower than the function's.</li>
                    <li><strong>Watch an optimisation remove a variable.</strong> The same file at <code>-O2</code> loses the <code>local</code> variable DIE entirely, and the <code>sum_table</code> subprogram may vanish too if it was inlined. The machine code is still correct; the description is simply no longer emitted because nothing needs it.</li>
                    <li><strong>Count instances against call sites.</strong> <code>inline.c</code> calls <code>dot</code> four times but inlines it three times &mdash; the one inside <code>magnitude2</code> is folded away by the optimiser. Compare the <code>DW_AT_call_line</code> values against the source and check they land on the right lines.</li>
                    <li><strong>Confirm the shared description.</strong> All three instances have <code>DW_AT_abstract_origin</code> pointing at the same offset. Open <code>&lt;0x127&gt;</code> in the dump and verify it has parameters and a <code>decl_line</code> but no <code>low_pc</code>. That asymmetry is the entire design.</li>
                </ul>
                <p>And the check that catches scope bugs in your own reader: for the <code>-O0</code> build, the number of DIEs at depth 2 or greater should be stable across small edits to the function bodies. A sudden drop usually means you are treating a <code>0</code> terminator as a DIE.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a <code>DW_TAG_inlined_subroutine</code> DIE has <code>DW_AT_abstract_origin</code>, <code>DW_AT_call_line</code> and <code>DW_AT_ranges</code>, and no <code>low_pc</code>/<code>high_pc</code> pair. What does each of those three attributes give a debugger, and what happens if a reader assumes the instance is one contiguous address range?</p>
                <div class="quiz" id="quiz-dwarf-scopes-1">
                    <button class="quiz-option" data-correct="true" data-explain="abstract_origin points at the shared DW_TAG_subprogram that carries the parameter and local descriptions; call_line says where in the source the call was written, which is what a user wants to see when stepping; ranges says the address coverage is fragmented. A reader that assumes one contiguous range tests pc against a single window and will fail to recognise the instance for part of the function, so its parameters and locals vanish from the frame view partway through." onclick="checkQuiz('quiz-dwarf-scopes-1', this)"><code>abstract_origin</code> reaches the shared parameter and local descriptions, <code>call_line</code> gives the source call site to show the user, and <code>ranges</code> says the code is split across several address windows &mdash; so a reader testing a single range will lose the frame partway through</button>
                    <button class="quiz-option" data-correct="false" data-explain="This conflates the instance DIE with the description DIE. The instance has no low_pc because it is not the function as written; it has ranges because the inlined body is fragmented. A DW_TAG_subprogram description is what lacks an address entirely, and that is the whole reason the two are separate DIEs." onclick="checkQuiz('quiz-dwarf-scopes-1', this)"><code>abstract_origin</code> gives the instance its own address range, <code>call_line</code> gives the parameter types, and the missing <code>low_pc</code> simply means the body was optimised away</button>
                    <button class="quiz-option" data-correct="false" data-explain="DW_AT_call_line is a source line, not an address, and it is what lets a debugger show which line of the caller contains the call. The instance's address information comes from DW_AT_ranges, and the reason the low_pc/high_pc pair is absent is that the inlined body is not one contiguous run of instructions." onclick="checkQuiz('quiz-dwarf-scopes-1', this)"><code>call_line</code> gives the machine address the body starts at, and the missing <code>low_pc</code> means the function was inlined more than once so no single start exists</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A colleague's debugger shows the correct parameter list at the start of an <code>-O2</code> build of <code>work</code>, but two of the three parameters disappear partway through, and stepping into <code>dot</code> shows no locals at all. Nothing crashes; the values are simply absent from the frame view. What is the single most likely cause, and what should you check to confirm it?</p>
                <div class="quiz" id="quiz-dwarf-scopes-2">
                    <button class="quiz-option" data-correct="true" data-explain="An inlined instance whose body was not emitted as one contiguous run carries DW_AT_ranges rather than low_pc/high_pc, and a reader that tests only a single window recognises the instance for the first fragment and not the rest. Confirm it by dumping DW_AT_ranges for every inlined instance: any instance that is a list rather than a pair is the one being dropped, and reading the low_pc/high_pc attributes on it would find neither present." onclick="checkQuiz('quiz-dwarf-scopes-2', this)">The reader is treating each inlined instance as one contiguous address range. Check whether any instance uses <code>DW_AT_ranges</code> instead of a <code>low_pc</code>/<code>high_pc</code> pair &mdash; in the reference build, one of the three does</button>
                    <button class="quiz-option" data-correct="false" data-explain="The description DIE and its instances are both present in the file, and abstract_origin is how the reader reaches the parameters. If the pointer were dangling the failure would be uniform across the whole function rather than beginning correctly and then degrading, which is the signature of a range test rather than of a missing reference." onclick="checkQuiz('quiz-dwarf-scopes-2', this)">The shared <code>DW_AT_abstract_origin</code> DIE is missing, so the instance DIEs have nothing to point at and the parameters cannot be resolved</button>
                    <button class="quiz-option" data-correct="false" data-explain="The opposite pattern: losing a lexical block would hide an inner-scope local, not a function parameter, and it would not be sensitive to position within the function. The symptom here is parameters disappearing with progress, which is an address-coverage problem in the instance DIE." onclick="checkQuiz('quiz-dwarf-scopes-2', this)">A <code>DW_TAG_lexical_block</code> DIE is being skipped, so variables inside an inner scope are dropped once execution leaves that block</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a debugger's output is correct at first and degrades later, suspect the address arithmetic, not the data. A missing record drops everything uniformly; a range that stops covering the code drops things progressively.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Scope nesting in DWARF is the same idea as block structure in the <a href="/courses/elf/lessons/symbol-table">ELF symbol table</a>, where a local symbol's binding and visibility say who may see it &mdash; and DWARF's tree makes that hierarchy explicit rather than leaving it to be inferred. The COFF course's <a href="/courses/coff/lessons/coff-symbol-table">storage class</a> covers the other half of the same question: which symbols exist outside the compilation unit at all.</p>
                <p><code>DW_AT_abstract_origin</code> is a reference used for deduplication, and the COFF course covers the other great deduplication mechanism in the toolchain: <a href="/courses/coff/lessons/coff-comdat">COMDAT</a>. Both exist because the same code gets emitted more than once, and both solve it by pointing at one authoritative copy rather than repeating it. Split DWARF, the next-but-one concept, is a third instance of the same instinct at the level of whole files.</p>
                <p>Scopes tell you which variables are live. The next concept is how a live variable is turned into an address, because for a local that address changes on every call.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-locations">Location Expressions</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-types">Previous: Types and Type Chains</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-locations">Next: Location Expressions</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
