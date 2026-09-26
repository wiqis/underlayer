// DWARF Course — Module 5: The Format on Other Inputs
// Concept: type units — the second kind of compilation unit, where they live in
// DWARF 4 versus 5, and what the 16 bytes labelled a "signature" actually contain.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dwarf_type_units() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Type Units — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson dwarf-lesson">
            <a href="/courses/dwarf" class="back-link">Back to course</a>
            <h1>Type Units</h1>
            <div class="lesson-meta">21 min &middot; Module 5: The Format on Other Inputs &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>One compilation unit, one source file, one <code>.debug_info</code> unit &mdash; that is the mental model from Module 3, and for a C program it is simply true. C++ breaks it, and it breaks it for a specific reason worth stating: <strong>the same type is described over and over.</strong> A header defining <code>std::string</code> is included by four hundred translation units, and if each one carries its own copy of the full <code>std::string</code> DIE tree, the debug info is four hundred times larger than it needs to be, and a linker merging them has four hundred structurally identical things to compare.</p>
                <p>The fix is to factor the type out of the compile unit. A <strong>type unit</strong> is a compilation unit whose job is to describe one type, given a name that identifies it independently of where it was found. The compile units then refer to that name rather than repeating the tree, and identical types from different files land in the same unit.</p>
                <p>Which makes type units the first place in DWARF where <em>identity is separated from location</em>. Everything so far in this course has said "the type is at offset X in this unit". A type unit says "the type is whatever has this signature" &mdash; and as this concept shows, that signature is not what its name suggests it is.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two header layouts, because type units predate version 5 by a long way and version 5 moved them.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">DWARF 4, in <code>.debug_types</code></th><th scope="col">DWARF 5, in <code>.debug_info</code></th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>unit_length</code></td><td>yes</td><td>yes</td></tr>
                        <tr><td><code>version</code></td><td>yes</td><td>yes</td></tr>
                        <tr><td><code>unit_type</code></td><td>&mdash; implied by the section</td><td><code>DW_UT_type</code> = 2</td></tr>
                        <tr><td><code>address_size</code></td><td>yes</td><td>yes</td></tr>
                        <tr><td><code>debug_abbrev_offset</code></td><td>yes</td><td>yes</td></tr>
                        <tr><td><code>type_signature</code></td><td>yes, 16 bytes</td><td>yes, 16 bytes</td></tr>
                        <tr><td><code>type_offset</code></td><td>yes</td><td>yes</td></tr>
                    </tbody>
                </table>
                <p>Read the version 4 column as what a reader learns from the <em>section name</em> instead of a field: anything in <code>.debug_types</code> is a type unit, and anything in <code>.debug_info</code> is a compile unit, and the two can never be confused. That is a genuinely nice property of the older design and version 5 gave it up &mdash; because it bought something else, which is the next section.</p>
                <h3>Why version 5 moved them into <code>.debug_info</code></h3>
                <p>Compile the same file both ways and the difference is not subtle:</p>
                <div class="hex-dump">
                    <pre>$ gcc -gdwarf-4 -fdebug-types-section -c t.c -o v4t.o
$ readelf -S -W v4t.o | grep -c '\.debug_types '        ->  1

$ gcc -gdwarf-5 -fdebug-types-section -c t.c -o types.o
$ readelf -S -W types.o | grep -c '\.debug_types '      ->  0
$ readelf --debug-dump=info types.o | grep 'Unit Type'
  Unit Type:     DW_UT_type (2)
</pre>
                </div>
                <p>The version 5 build has <strong>no <code>.debug_types</code> section at all</strong>, and the type unit is sitting in <code>.debug_info</code> where <code>readelf</code> reports it by its <code>unit_type</code>. This is a real, checkable relocation of a structure, and it is the kind of change that breaks every tool that walked <code>.debug_info</code> assuming every unit in it was a compile unit.</p>
                <p>The reason is worth knowing because it is the same reason as a great many format decisions: <strong>a section has overhead, and units do not divide evenly into sections.</strong> A file with one type unit and one compile unit used to need two sections, each with a section header, an alignment requirement, and an entry in the relocatable object. In version 5 they share one. The cost is that the unit header grew by the <code>unit_type</code> byte you decoded in the previous concept; the benefit is that the boundary between "compile units" and "type units" stops being a section boundary and becomes a <em>value</em>, which is far cheaper to extend &mdash; version 5 added split units and partial units in exactly this space, and neither needed a new section.</p>
                <div class="callout">
                    <strong>That is the pattern to carry forward.</strong> Whenever a format has two ways to say the same thing &mdash; a section boundary or a field &mdash; the field wins over time, because fields compose. Version 4 said "which kind of unit am I" with the section name; version 5 says it with a byte in the header; and having said it with a byte, adding a fifth kind of unit became a matter of defining a new value rather than inventing a container.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Decoding the version 5 header by hand</h3>
                <p>The type unit is the first thing in <code>.debug_info</code> of the version 5 build. The whole header, 32 bytes:</p>
                <div class="hex-dump">
                    <pre>0000: 67 00 00 00 05 00 02 08 00 00 00 00 89 5c 02 be
0010: e0 73 7e 69 23 00 00 00 01 1d 03 47 23 00 00 00 01 1d
</pre>
                </div>
                <table>
                    <thead>
                        <tr><th scope="col">Bytes</th><th scope="col">Field</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>67 00 00 00</code></td><td><code>unit_length</code></td><td>103</td></tr>
                        <tr><td><code>05 00</code></td><td><code>version</code></td><td>5</td></tr>
                        <tr><td><code>02</code></td><td><code>unit_type</code></td><td><code>DW_UT_type</code> = 2</td></tr>
                        <tr><td><code>08</code></td><td><code>address_size</code></td><td>8</td></tr>
                        <tr><td><code>00 00 00 00</code></td><td><code>debug_abbrev_offset</code></td><td>0</td></tr>
                        <tr><td><code>89 5c 02 be e0 73 7e 69 23 00 00 00 01 1d 03 47</code></td><td><code>type_signature</code></td><td>16 bytes</td></tr>
                        <tr><td><code>23 00 00 00</code></td><td><code>type_offset</code></td><td><code>0x23</code> = 35</td></tr>
                        <tr><td><code>01</code></td><td>first abbrev code</td><td>the type DIE begins at <code>0x23</code></td></tr>
                    </tbody>
                </table>
                <p>One thing to check before trusting the table: <code>type_offset</code> is <code>0x23</code>, and the unit's <code>unit_length</code> is 103, so the type DIE starts 35 bytes into a 107-byte unit. That is a plausible position &mdash; there is a root DIE and some type DIEs before the named type. And <code>readelf</code> independently reports <code>Type Offset: 0x23</code>, which is the cross-check that matters.</p>
                <h3>The version 4 header, for contrast</h3>
                <p>Same source, version 4, in <code>.debug_types</code>:</p>
                <div class="hex-dump">
                    <pre>0000: 61 00 00 00 04 00 00 00 00 00 08 89 5c 02 be e0
0010: 73 7e 69 1d 00 00 00 01 0c 00 00 01 0c 00 00 00 00 02 53
</pre>
                </div>
                <p>Eleven bytes of the standard version 4 header &mdash; no <code>unit_type</code> &mdash; then the signature at offset <code>0x0b</code>, then <code>type_offset</code>. Compare the two signature fields directly:</p>
                <div class="hex-dump">
                    <pre>v4, in .debug_types:  89 5c 02 be  e0 73 7e 69  1d 00 00 00  01 0c 00 00
v5, in .debug_info :  89 5c 02 be  e0 73 7e 69  23 00 00 00  01 1d 03 47
                                ^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^
                                IDENTICAL          type_offset      differs
</pre>
                </div>
                <h3>What the 16 bytes labelled a signature actually contain</h3>
                <p>Both readers agree on the version 4 unit and report the same signature:</p>
                <pre><code>$ readelf --debug-dump=info types.o   | grep Signature
  Signature:     0x697e73e0be025c89
$ readelf --debug-dump=info v4t.o   | grep Signature
  Signature:     0x697e73e0be025c89</code></pre>
                <p>Identical. The same type, compiled by the same compiler at two different DWARF versions, has the same signature as far as <code>readelf</code> is concerned. And yet the two sixteen-byte fields in the files are <em>not</em> identical. Decompose both into four 32-bit words:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Word</th><th scope="col">Version 4</th><th scope="col">Version 5</th><th scope="col">Same?</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>u32[0]</code></td><td><code>0xbe025c89</code></td><td><code>0xbe025c89</code></td><td>yes</td></tr>
                        <tr><td><code>u32[1]</code></td><td><code>0x697e73e0</code></td><td><code>0x697e73e0</code></td><td>yes</td></tr>
                        <tr><td><code>u32[2]</code></td><td><code>0x0000001d</code></td><td><code>0x00000023</code></td><td><strong>no</strong></td></tr>
                        <tr><td><code>u32[3]</code></td><td><code>0x00000c01</code></td><td><code>0x47031d01</code></td><td><strong>no</strong></td></tr>
                    </tbody>
                </table>
                <p>And here is the part that makes this worth a concept. <code>u32[2]</code> is <strong>the <code>type_offset</code> field</strong>, sitting inside the signature:</p>
                <div class="hex-dump">
                    <pre>v4  u32[2] = 0x0000001d = 29   and readelf's Type Offset for v4 is 0x1d
v5  u32[2] = 0x00000023 = 35   and readelf's Type Offset for v5 is 0x23
</pre>
                </div>
                <p>Both match, exactly, in both files. So the sixteen bytes called a <em>type signature</em> are not sixteen opaque hash bytes: <strong>the third word is a copy of the unit's own <code>type_offset</code></strong>, and the fourth word is the only part that looks like a hash.</p>
                <div class="callout callout-warn">
                    <strong>What is established, and what is not.</strong>
                    <br /><br />
                    <strong>Established, from the bytes:</strong> the first eight bytes are identical across the two versions; the third word equals <code>type_offset</code> in both; <code>readelf</code> prints only the first eight bytes as a 64-bit value; and <code>u32[3]</code> is the only word that differs in a way not already explained by the offset.
                    <br /><br />
                    <strong>Not established:</strong> why the offset is in there. A plausible story is that the field is a hash over a canonicalised form of the type that happens to include the DIE's own position, which would make it version-dependent &mdash; and that <em>would</em> be a defect, because a signature whose purpose is to be comparable across compilations should not depend on encoding details. But a plausible story is not a finding, and no second implementation exists on this machine to ask. So the concept states the structure, states that <code>readelf</code> shows you half of it, and leaves the reason open. If you work it out, that is a real result and it belongs in a reader.
                </div>
                <p>And the practical consequence of <code>readelf</code> showing you only eight bytes: <strong>two type units with the same displayed signature are not thereby known to be the same type.</strong> They could differ in the half you were not shown. Any tool that treats the displayed value as the whole signature is making an assumption it has not checked, and the assumption is wrong in at least one direction here &mdash; the same type in two versions <em>does</em> produce different full signatures.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>How a reader uses this, and where the two versions genuinely differ rather than merely look different. The reference form is <code>DW_FORM_ref_sig8</code>: an eight-byte value that is <em>not</em> an offset into <code>.debug_info</code> but a type signature, to be resolved by searching for the type unit that claims it.</p>
                <div class="formula">
walk every unit in .debug_info (or .debug_types, in v4)
    if unit_type != DW_UT_type:
        skip it -- it is a compile or split unit
    record unit.type_signature -> unit

when a DW_FORM_ref_sig8 attribute is read:
    signature = the 8 bytes from the attribute
    if signature in the recorded map:
        the referenced DIE is in that unit, at unit.type_offset
    else:
        the reference is dangling: the type unit is missing
        (this happens after -gdwarf-4 -fdebug-types-section is
         compiled without it, and in any stripped or partial file)
</div>
                <p>Two properties of that algorithm are worth naming, and both come from the design rather than from the code.</p>
                <p><strong>It is a two-pass algorithm, and the first pass is global.</strong> A <code>DW_FORM_ref_sig8</code> in the first unit of a file can refer to a type unit at the end of the file, or in another file entirely, or in a <code>.dwp</code> package. There is no "the target is nearby" assumption available, so the index must be built before any reference can be resolved. A reader that resolves references as it walks will fail on exactly the units that use them.</p>
                <p><strong>The failure mode is a dangling reference, not a wrong one.</strong> If the signature is not in the index, there is no fallback that produces a plausible answer &mdash; there is simply no type. That is unusual and valuable. Compare it with a <code>DW_FORM_ref_addr</code>, where a stale offset silently resolves to whatever DIE now lives there: same size, plausible structure, wrong type. <strong>A signature-based reference fails loudly; an offset-based reference fails silently.</strong> That is a real argument for the whole indirection, and it is the mirror image of what the <a href="/courses/dwarf/lessons/dwarf-portability">portability concept</a> found about indexed addresses.</p>
                <p>Which also explains why the signature is worth having even though the mechanism above does not verify it. The signature's job is to let a linker merge two type units that describe the same type, and to let a debugger share one copy across four hundred files. Both jobs are <em>optimisation</em> jobs &mdash; the debug info is correct without them. And that is exactly why the unverified half matters: a signature that collided or drifted would not make the debug info wrong, it would make a linker merge two different types, and the result would be a program whose types are subtly wrong with no diagnostic anywhere. The field is load-bearing precisely where nobody is looking.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ gcc -gdwarf-4 -fdebug-types-section -O0 -c t.c -o v4t.o
$ gcc -gdwarf-5 -fdebug-types-section -O0 -c t.c -o types.o
$ readelf -S -W v4t.o | grep -oE '\.debug_[a-z_]+'
$ readelf --debug-dump=info types.o | grep -E 'Unit Type|Signature|Type Offset'</code></pre>
                <ul>
                    <li><strong>Decompose the signature yourself.</strong> Read the sixteen bytes out of each file at the offsets this concept gives, split them into four 32-bit words, and check the third word against <code>readelf</code>'s <code>Type Offset</code> for both versions. Then confirm that <code>readelf</code>'s printed 64-bit value is words 0 and 1 only. Five minutes, and you will never again assume a displayed signature is the whole field.</li>
                    <li><strong>Find a case where the halves disagree usefully.</strong> Compile with <code>-gdwarf-2</code> and <code>-gdwarf-3</code> and <code>-fdebug-types-section</code> as well. If <code>u32[0]</code> and <code>u32[1]</code> stay fixed while the offset word moves, you have isolated which part of the field is encoding-dependent. If they move too, the field is encoding-dependent throughout and the version 4 versus 5 match was the coincidence.</li>
                    <li><strong>Make the dangling reference happen.</strong> Compile with <code>-gdwarf-5 -fdebug-types-section</code>, note a <code>DW_FORM_ref_sig8</code> value, then recompile <em>without</em> the flag and look for the reference that no longer resolves. It is the cleanest demonstration available of a reference that fails loudly instead of resolving to the wrong thing.</li>
                    <li><strong>Count the deduplication on a real header.</strong> Take a C++ file that includes several standard headers, compile with the flag, and compare <code>.debug_info</code>'s size with and without it. Then count how many type units there are and how many <code>DW_FORM_ref_sig8</code> references point at them. The ratio is the size argument, measured rather than asserted.</li>
                    <li><strong>Write the two-pass index.</strong> Extend the decoder shipped with this course to skip non-type units, record signatures, and resolve <code>DW_FORM_ref_sig8</code>. Then point it at the version 5 file and confirm it agrees with <code>readelf</code> on which unit each reference lands in. It is about thirty lines and it is the only way to find out whether the offset word inside the signature agrees with the header's own <code>type_offset</code> &mdash; two fields that ought to be redundant.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: the same type is compiled at DWARF 4 and at DWARF 5. <code>readelf</code> reports <code>Signature: 0x697e73e0be025c89</code> for both units. The two sixteen-byte fields in the files are <code>89 5c 02 be e0 73 7e 69 1d 00 00 00 01 0c 00 00</code> and <code>89 5c 02 be e0 73 7e 69 23 00 00 00 01 1d 03 47</code>, and the two <code>Type Offset</code> values are <code>0x1d</code> and <code>0x23</code>. What can you conclude, and what must you not conclude?</p>
                <div class="quiz" id="quiz-dwarf-type-units-1">
                    <button class="quiz-option" data-correct="true" data-explain="The signature decomposes cleanly and one word is plainly structural: u32[2] is 0x1d in one file and 0x23 in the other, which are exactly the two reported type offsets, so the third word is a copy of the header's own type_offset rather than hash material. Words 0 and 1 are byte-identical across versions, which is why readelf's 64-bit display matches. Word 3 differs and is the only part that is not already explained. So the field is part offset and part something opaque, readelf shows only the opaque-and-stable half, and the honest conclusion stops short of saying why. The trap this catches is treating the displayed 64-bit value as the whole signature: two units showing the same signature have not thereby been shown to be the same type." onclick="checkQuiz('quiz-dwarf-type-units-1', this)">The signature is not sixteen opaque bytes. Its third 32-bit word is the unit's own <code>type_offset</code> in both files, its first eight bytes are version-stable and are all <code>readelf</code> prints, and only the fourth word is unexplained. So the two units have the same <em>displayed</em> signature but provably different full signatures</button>
                    <button class="quiz-option" data-correct="false" data-explain="The sixteen bytes in the two files differ in the last eight, and one of those differences is exactly the type offset, so the fields are demonstrably not equal. What is equal is the eight bytes readelf chose to display. A tool comparing the whole sixteen bytes would find a difference; a tool comparing what readelf prints would not, and that gap is the whole point of the question." onclick="checkQuiz('quiz-dwarf-type-units-1', this)">The two type units are byte-identical, so a type signature is fully portable across DWARF versions and can safely be compared across tools and files</button>
                    <button class="quiz-option" data-correct="false" data-explain="That is a misreading of which bytes readelf shows. Its 64-bit value is words 0 and 1, the first eight bytes, which do match. Word 2 is the type offset and word 3 differs, so the matching half is exactly the half readelf displays and the differing half is exactly the half it hides. The conclusion about not assuming is right; the reason is inverted." onclick="checkQuiz('quiz-dwarf-type-units-1', this)">readelf is printing the last eight bytes, and those are the ones that differ, so the identical display is a coincidence of formatting and the signatures should be assumed different</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your build links correctly and your tests pass, but a colleague notices that one translation unit's view of a shared type shows a member that the other translation unit's view does not. Both were compiled with the same compiler, the same flags and the same DWARF version, from the same header, on the same day. The two objects' debug info is enormous. Given this concept, what is the most likely mechanism, and what single change would convert the failure from silent into loud?</p>
                <div class="quiz" id="quiz-dwarf-type-units-2">
                    <button class="quiz-option" data-correct="true" data-explain="This is the failure mode type units exist to prevent, and the detail that matters is that nothing reports it. Two files describe the same type, a linker compares signatures, and a collision or a drift in the fourth word merges two different descriptions. The result is a debug-info view in which a member exists in one object and not the other, which is a type-level inconsistency with no runtime consequence and therefore no test failure. Converting it to loud means bypassing the signature: resolve every DW_FORM_ref_sig8 by comparing the type's actual DIE tree rather than by trusting the field. That is slower, and slowness is the entire cost of the optimisation, so the exercise is worth doing deliberately in a verification build. The general habit is that an identity field which enables a merge is the one place where a silent merge is most damaging, because the merge is an optimisation and optimisations are exactly what nobody verifies." onclick="checkQuiz('quiz-dwarf-type-units-2', this)">A type signature collided, so a linker merged two type units that describe different types. The change is to have your tool resolve <code>DW_FORM_ref_sig8</code> by comparing the actual DIE trees instead of trusting the signature, so a mismatch becomes an error</button>
                    <button class="quiz-option" data-correct="false" data-explain="Plausible and worth ruling out, but it does not fit the facts you were given. The objects were built with the same compiler, the same flags and the same DWARF version on the same day, so the producer strings should be identical, and an encoding difference between the two is not available. The enormous debug info is the opposite of a clue pointing away from duplication, since that is what type units are for." onclick="checkQuiz('quiz-dwarf-type-units-2', this)">The two files disagree about the type's size or alignment, and the linker is applying the first definition to both, so the views diverge</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real class of bug and it is the one to suspect first in most projects, but it does not match the evidence. If only one translation unit had the flag, the other would carry the full type inline and there would be no signature to collide; both would still agree on the type, because a compile unit describes its own types regardless. The symptom of a member appearing in one view and not the other is a merged type description, not a duplicated one." onclick="checkQuiz('quiz-dwarf-type-units-2', this)">Only one of the two files was compiled with <code>-fdebug-types-section</code>, so only one has type units and the other inlines the type, and the two encodings disagree</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a field whose only job is to let something be merged or skipped is a field nobody checks. When a silent wrong answer is possible, prefer the slower comparison that can fail, at least once, on purpose.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the payoff for the two sentences in <a href="/courses/dwarf/lessons/dwarf-split">the split-debugging concept</a> that said a skeleton carries an 8-byte <code>dwo_id</code> where a type unit would carry a 16-byte signature and offset. That was a comparison of two headers nobody had looked at. It has now been looked at, and the 16 bytes have a structure &mdash; which means the two identifier schemes are more alike than the sentence implied, since both carry a position alongside the identity.</p>
                <p>It is also the answer to a question the <a href="/courses/dwarf/lessons/dwarf-types">types concept</a> had to leave open: following a <code>DW_AT_type</code> chain is straightforward inside one unit and genuinely awkward across them, because a reference can leave the unit you are reading. This concept supplies the join. The general rule across all of DWARF is that a reference is either an <strong>offset</strong> &mdash; cheap, local, fails silently when stale &mdash; or a <strong>signature</strong> &mdash; expensive, global, fails loudly. Version 5 moved a lot of the format from the first kind to the second, and the reason is exactly that second property.</p>
                <p><code>unit_type</code> is a value and values compose, so version 5 could add kinds without adding sections. It has since added three more: <code>DW_UT_partial</code> for a unit whose abbrev table is shared with a unit elsewhere, and <code>DW_UT_split_compile</code> and <code>DW_UT_split_type</code> for the skeleton and split halves of <a href="/courses/dwarf/lessons/dwarf-split">split debugging</a>. Only the type unit carries a signature, and only the split compile unit carries a <code>dwo_id</code> &mdash; which is the whole reason those two header fields are optional, and a reader that reads them unconditionally reads sixteen bytes of the next unit.</p>
                <p>The remaining unit kind that appears in real files and is not yet decoded here is <code>DW_UT_partial</code>. It is the rarest of the four and it exists for a narrow reason: a producer that emits many units sharing one abbrev table can say "read my abbreviations from over there" instead of duplicating them. It is the unit-kind version of the indexed-string idea, and the same trade &mdash; smaller output, a global lookup, a reference that fails loudly if the other unit is missing.</p>
                <p>What comes next is a different kind of question entirely. So far every concept has asked <em>where is this thing</em>. The call-site information asks <em>what happened here</em>: not what a variable is, or what a type is, but what the program was doing at a return address. That is a different question about the same DIE tree, and it is the last of the four unit-shaped features this module covers.</p>
                <p>Next: <a href="/courses/dwarf/lessons/dwarf-call-sites">Call Sites</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/dwarf/lessons/dwarf-v4">Previous: DWARF 4 in Practice</a></span>
                <span><a href="/courses/dwarf/lessons/dwarf-call-sites">Next: Call Sites</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
