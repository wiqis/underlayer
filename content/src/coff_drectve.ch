// COFF Course — Module 5: Other Targets and Other Sections
// Concept: .drectve — a section whose contents are instructions to the linker,
// decoded from 23 bytes, and observed being discarded.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_drectve() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Linker Directives in a Section — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>Linker Directives in a Section</h1>
            <div class="lesson-meta">18 min &middot; Module 5: Other Targets and Other Sections &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every section in Modules 1 to 4 held data for the program. <code>.text</code> holds instructions, <code>.data</code> holds initialised values, <code>.rdata</code> holds things that should not be written, and the COMDAT sections hold code that one object is allowed not to contribute. In every case the contents are the program's contents.</p>
                <p><code>.drectve</code> is a section whose contents are <strong>not the program's contents at all.</strong> They are text addressed to the linker: options, exactly the kind you would type on a command line, produced by a <code>#pragma</code> in a source file and carried in the object so that a build does not have to know about them. The compiler cannot apply them, because it does not know the link context; only the linker can. So it writes them down and gets out of the way.</p>
                <p>It is a small idea and it is the clearest example in the course of a section as a <em>channel</em> rather than a container. And it has a property that makes it worth the last concept of the module: <strong>the section does not survive the link.</strong> The linker reads it, obeys it, and discards it, and the map file records the discarding. So it is a section whose entire purpose is to not be in the output &mdash; which is a good final note for a module about the parts of a format that exist outside the program.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Produce one. A single pragma, on a line that looks like a comment:</p>
                <p>Three lines: a pragma, and two one-line functions where <code>bar</code> calls <code>foo</code>.</p>
<pre><code>$ cat directive_used.c
#pragma comment(linker, "/alternatename:foo=bar")

$ clang --target=i686-pc-windows-msvc -c directive_used.c -o directive_used.obj
$ llvm-readobj --sections directive_used.obj | grep drectve
  Name: .drectve (2E 64 72 65 63 74 76 65)</code></pre>
                <p>A section named <code>.drectve</code> appears, and nothing else about the object changes. The section's entire contents:</p>
                <div class="hex-dump">
                    <pre>size = 23 bytes

20 2f 61 6c 74 65 72 6e 61 74 65 6e 61 6d 65 3a 66 6f 6f 3d 62 61 72
 |  |  |                                          |                       |
 |  |  |                                          |                       +-- "bar"
 |  |  |                                          +-------------------------- "foo"
 |  |  +---------------------------------------------------------- "alternatename:"
 |  +------------------------------------------------------------- "/"
 +-------------------------------------------------------------------- " " (space)
</pre>
                </div>
                <p>So the encoding is trivially simple, and the leading byte is the only subtlety: <strong>a space, not a NUL and not a length.</strong> The section's <code>SizeOfRawData</code> is the length of the whole blob, and the payload is space-separated linker options. Every option begins with a <code>/</code>, which is the MSVC convention, and a comma between options is also permitted.</p>
                <p>Read the option itself: <code>/alternatename:foo=bar</code>. It means <em>"wherever the symbol <code>foo</code> is referenced and undefined, call it <code>bar</code> instead"</em>. That is a real, widely used directive &mdash; it is how a program overrides a library function, and how <code>kernel32</code> redirects to <code>api-ms-win-*</code> sets work. So the section contains an instruction that <strong>rewrites the program's symbol resolution</strong>, and the program has no bytes for it at all.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The characteristics say the same thing twice</h3>
                <p>Read the section header with the parser shipped with this course:</p>
                <pre><code>section .drectve  rawsize=23  char=0x00100a00
  -> ['IMAGE_SCN_LNK_INFO', 'IMAGE_SCN_LNK_REMOVE']</code></pre>
                <p>Two flags, and they are the whole story of this section's life:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Flag</th><th scope="col">Bit</th><th scope="col">Means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>IMAGE_SCN_LNK_INFO</code></td><td><code>0x00000200</code></td><td>This section is <em>for</em> the linker. It is not program data and not to be placed</td></tr>
                        <tr><td><code>IMAGE_SCN_LNK_REMOVE</code></td><td><code>0x00000800</code></td><td>Remove it. Do not put it in the output at all</td></tr>
                    </tbody>
                </table>
                <p>And the alignment bits, <code>0x00100000</code>, say 16-byte alignment for a section that will never occupy an address. <strong>Which is the neat observation: the format sets alignment requirements on a section whose entire purpose is to not exist in the output.</strong> The alignment is a property of the input record, not of anything placed, and it is a leftover of the general rule that every section carries alignment rather than only the ones that need it.</p>
                <p>Note also what is <em>not</em> here, by comparison with the other sections in this object. No <code>MEM_READ</code>, no <code>MEM_EXECUTE</code>, no <code>CNT_CODE</code>, no <code>CNT_INITIALIZED_DATA</code>. The characteristics do not describe the data at all, because the data is not data. They describe the section's <strong>relationship to the linker</strong>, and the only content flags present are the two that express that relationship.</p>
                <h3>Observed being discarded</h3>
                <p>Now the part that closes the loop. Link the object and look at the map file, the same technique the <a href="/courses/coff/lessons/coff-map-files">map files concept</a> used to watch <code>.debug$S</code> and <code>.llvm_addrsig</code> disappear:</p>
                <pre><code>$ ld --oformat pei-i386 -m i386pe directive_used.obj -o out.exe --entry bar -Map out.map
$ grep -A6 'Discarded input sections' out.map
 .drectve       0x00000000      0x17 directive_used.obj
 .debug$S       0x00000000      0x5c directive_used.obj
 .llvm_addrsig  0x00000000       0x1 directive_used.obj</code></pre>
                <p><code>.drectve</code> is in the discard list, at <code>0x17</code> = 23 bytes, which is exactly the section's size. And the control is worth running, because it is the cleanest possible demonstration that the discard is caused by the pragma and not by something incidental:</p>
                <pre><code>$ cat directive.c            # the same source WITHOUT the pragma
# (the two one-line functions, no pragma)

$ clang --target=i686-pc-windows-msvc -c directive.c -o directive.obj
$ grep -A6 'Discarded input sections' plain.map
 .debug$S       0x00000000      0x5c directive.obj
 .llvm_addrsig  0x00000000       0x1 directive.obj</code></pre>
                <p>No <code>.drectve</code> row. Same compiler, same flags, same day, same everything &mdash; the only difference is the <code>#pragma</code>, and the section appears and is discarded. <strong>Cause established by controlled comparison rather than by inference from a flag.</strong></p>
                <h3>Why the linker obeys a string</h3>
                <p>Worth being explicit about, because it is unusual. The linker <em>parses</em> the contents: it reads <code>/alternatename</code>, splits on the colon, reads the two symbol names, and installs a rule in its resolution table. That is a text protocol, not a fixed-layout record. The format specifies:</p>
                <ul>
                    <li>a <strong>space</strong> (or a comma) between options, and a leading space is conventional</li>
                    <li>a leading <code>/</code> on every option</li>
                    <li>that the <strong>option names are the linker's</strong>, not the compiler's, and that the set is open-ended</li>
                </ul>
                <p>So the format has delegated the vocabulary to the tool. A new linker option needs no format change, needs no new field, and is simply understood by a newer linker &mdash; which is how a closed binary format ends up with an open extension point. It is the same instinct as the <code>ar</code> archive's symbol index in Module 3: a small, general container plus a tool-defined payload.</p>
                <div class="callout callout-warn">
                    <strong>The portability price, stated honestly.</strong> Because the payload is free text interpreted by one specific linker, a <code>.drectve</code> section is <strong>not portable between linkers</strong>. Hand the object to a linker that does not implement <code>/alternatename</code> and the section is not rejected &mdash; the <code>LNK_REMOVE</code> flag still removes it &mdash; it is silently <em>ignored</em>, and the redirection you asked for does not happen. The program links, runs, and calls the original symbol. There is no error, because from the linker's point of view it did exactly what it was told with an option it did not recognise.
                    <br /><br />
                    This is the general hazard of text protocols inside binary formats, and it is worth naming as a design lesson rather than only as a gotcha: <em>an open extension point trades away error detection</em>. A fixed-layout record with a type code can be rejected when the code is unknown. Free text cannot, because there is nothing to reject &mdash; it is just words.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a tool has to know about <code>.drectve</code>, and the trap that catches anyone who does not. The section is invisible in the output, so every question about it has to be answered <em>before</em> the link.</p>
                <div class="formula">
WHO NEEDS TO KNOW .drectve EXISTS, AND WHY

the linker
    must read it, or the directives are silently lost
    -> this is why LNK_INFO is set at all

an object-file dumper
    must not present 23 bytes of linker text as program data
    -> check IMAGE_SCN_LNK_INFO before printing contents

a security scanner
    must not skip it
    -> /alternatename can redirect a call to another symbol,
       so this section changes which function runs

a binary differ
    sees no difference at all
    -> two objects differing only in .drectve produce
       programs that differ only in behaviour, and the
       difference is invisible in the linked image

a linker that does not implement the option
    removes the section anyway
    -> no diagnostic; the redirection silently does not happen
</div>
                <p>The two rows in the middle are the ones that matter in practice, and they pull in opposite directions. A dumper wants to hide the section, because showing 23 bytes of <code>/alternatename:foo=bar</code> as though it were data is misleading. A security scanner wants to surface it, because <code>/alternatename</code> is a mechanism for <strong>changing which function a call reaches</strong> &mdash; which is exactly the shape of a thing worth reviewing, and exactly the sort of thing that would be missed by a tool that treats every section as either code or data.</p>
                <p>And the fourth row is the most unsettling, so it is worth sitting with. <strong>Two objects that differ only in their <code>.drectve</code> sections link to byte-identical images</strong> if the directives resolve to the same thing, and to <em>behaviourally different</em> programs if they do not. The section is consumed and the evidence is destroyed. That is a real property of the design rather than a defect &mdash; the information was only ever meant to be read once, by the one process that could act on it &mdash; but it means a build's reproducibility cannot be checked by comparing binaries. <code>/alternatename</code> and a handful of other options can change what a binary <em>does</em> without changing a byte of it.</p>
                <p>The honest summary of the whole module is in that sentence. TLS, weak externals and directives all store something outside the program: a per-thread base, a permitted-absence decision, and a text instruction to the linker. None of the three is in the output, all three change what the output does, and a format that has to carry them has to make room for sections that are not program data. The flags in the section header are how it says so &mdash; and, as this concept shows, the only reliable way to identify such a section is that the flags say so, because the name is the one thing a tool is tempted to rely on instead.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=i686-pc-windows-msvc -c directive_used.c -o directive_used.obj
$ llvm-readobj --sections directive_used.obj
$ ld --oformat pei-i386 -m i386pe directive_used.obj -o out.exe --entry bar -Map out.map</code></pre>
                <ul>
                    <li><strong>Accumulate directives and watch the format.</strong> Add three pragmas to one file and confirm the section grows by exactly the sum of their lengths, and that the options are separated by a single space. Then put two on one line, comma-separated, and check that both forms are accepted. The encoding has almost no structure, and confirming that is what makes the "free text" claim concrete rather than rhetorical.</li>
                    <li><strong>Find a directive that changes the output.</strong> <code>/alternatename</code> is the interesting one. Define <code>foo</code> in one object, reference it weakly or not at all from another, and use the pragma to redirect the reference. Then check whether the linked image's <code>bar</code> actually calls <code>foo</code>'s code. <strong>Do this before and after the <code>.drectve</code> is discarded</strong>, because the point is that the behaviour difference is real and the byte difference is nil.</li>
                    <li><strong>Test the silent-ignore failure.</strong> Feed the object to a linker that does not implement the option, if you can find one, or reason precisely about what it must do given only the flags. The section is removed by <code>LNK_REMOVE</code> regardless of whether the option was understood, so the failure is unavoidable by construction. Write down why no conforming linker could do better, and whether the specification requires it to warn.</li>
                    <li><strong>Compare against the other discarded sections.</strong> <code>.drectve</code>, <code>.debug$S</code> and <code>.llvm_addrsig</code> are all discarded, and all three are discarded for different reasons: linker instructions, a compiler's own metadata, and a section the compiler reserves for itself. Read all three flag sets and write down the distinction, because "discarded" is not one behaviour.</li>
                    <li><strong>Check the long-name path.</strong> <code>.drectve</code> is eight characters, which just fits the section-name field. Produce a pragma that makes the section name longer if you can, or simply note that this section is one of the few in this object whose name fits exactly. It is worth knowing which names go through the string table and which do not.</li>
                    <li><strong>Look for <code>.drectve</code> in a real binary.</strong> You will not find it, because it is discarded &mdash; so instead find the <em>effects</em>. A Windows system directory full of <code>api-ms-win-*</code> stubs exists because of this mechanism. Tracing one of those back to a <code>.drectve</code> is the most satisfying way to close this concept, because it shows the section doing its job on a scale of thousands of objects.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an object has a section <code>.drectve</code>, 23 bytes of contents beginning with a space, and characteristics <code>0x00100a00</code>. Its <code>SizeOfRawData</code> is 23. The linked image has no section of that name, and the map file lists <code>.drectve 0x00000000 0x17 directive_used.obj</code> among the discarded input sections. What did the linker do with those 23 bytes, and what would have happened if the characteristics had not included <code>IMAGE_SCN_LNK_REMOVE</code>?</p>
                <div class="quiz" id="quiz-coff-drectve-1">
                    <button class="quiz-option" data-correct="true" data-explain="Both halves are the concept. The linker read the contents, parsed the option out of the free text, installed the redirection in its symbol resolution, and then discarded the section because LNK_REMOVE was set, which is what the map row records. Without that flag the section would be treated as ordinary data and placed into the output, taking 23 bytes of address space and appearing in the image as a section holding linker text. That is not merely untidy: a section whose declared content is an instruction to the linker would then be present in the program, reachable in principle and meaningless in practice, and the LNK_INFO flag would be the only thing distinguishing it. The two flags together express the section's whole role: information addressed to the linker, and not part of the output." onclick="checkQuiz('quiz-coff-drectve-1', this)">It parsed the option, obeyed it, and discarded the section &mdash; the map row is the evidence. Without <code>LNK_REMOVE</code> the 23 bytes would be <em>placed into the image</em> as a section of program data, occupying address space and holding linker text</button>
                    <button class="quiz-option" data-correct="false" data-explain="That inverts the role of the two flags. LNK_REMOVE is the instruction not to place the section, and it is what the discard list is recording, so without it the section would be placed. IMAGE_SCN_LNK_INFO marks the section as being addressed to the linker; it says who the contents are for, not whether they are kept. Both flags are present here, and it is the one you are asking about that decides placement." onclick="checkQuiz('quiz-coff-drectve-1', this)">It ignored the contents and discarded the section anyway, because <code>IMAGE_SCN_LNK_INFO</code> tells the linker the section is not program data and must not be placed</button>
                    <button class="quiz-option" data-correct="false" data-explain="The map row shows the section is present in the input and absent from the output, and this flag is exactly what produces that. Without it the section would be placed like any other, so the discard is caused by the flag's presence rather than its absence. And the section did not simply pass through, because a pass-through would leave a 23-byte section in the image, which the map would show as a placement rather than a discard." onclick="checkQuiz('quiz-coff-drectve-1', this)">It would have copied the 23 bytes into the output as a <code>.drectve</code> section, so the option would still be readable in the shipped binary for later auditing</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your team ships a shared library built from vendored third-party sources. Two builds of the same commit, on two machines, produce binaries of identical size whose every section matches byte for byte &mdash; and the two libraries behave differently: one of them calls your logging function, the other calls the third party's. You have both objects and both link scripts. Given this concept, what is the most likely explanation, and what is the one check that settles it?</p>
                <div class="quiz" id="quiz-coff-drectve-2">
                    <button class="quiz-option" data-correct="true" data-explain="This is the concept's sharpest practical edge. The behaviour difference is real and the byte difference is nil, because /alternatename redirects a symbol reference at link time and the section carrying the instruction is then discarded. So a byte comparison of the two binaries proves nothing, and the obvious debugging step is guaranteed to come up empty. The distinguishing evidence is in the objects, where one has a 23-byte .drectve section and the other does not, and the section's contents name the two symbols. One command per object settles it. The general lesson is that binary comparison is a completeness check on the data, not a completeness check on the build, and any property the linker consumes is invisible to it by construction." onclick="checkQuiz('quiz-coff-drectve-2', this)">One of the objects carries a <code>.drectve</code> section containing an <code>/alternatename</code> directive that redirects the symbol, and the other does not. The check is to diff the two objects' section tables and read the <code>.drectve</code> contents, since the linked binaries are identical by design</button>
                    <button class="quiz-option" data-correct="false" data-explain="Worth checking, and the vendor source is a reasonable place to look, but the evidence rules it out. Identical source, identical section contents in both binaries, identical sizes: if the compiler had chosen differently on the two machines, the emitted code would differ and the sections would not match byte for byte. A compiler difference changes data, and this case is specifically characterised by the data being identical while the behaviour is not." onclick="checkQuiz('quiz-coff-drectve-2', this)">The two machines used different compiler versions, so the third-party source compiled to a different symbol reference on each</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when two binaries from one source are byte-identical but behave differently, the difference was consumed by the build. Go compare the inputs, and expect to find it in something the output cannot contain.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This closes the COFF course's format coverage, and the three sections in this module form a set worth stating as a whole. <a href="/courses/coff/lessons/coff-tls">TLS</a> carries what the loader needs, per thread. <a href="/courses/coff/lessons/coff-weak-externals">Weak externals</a> carry a link-time decision in a symbol's storage class. And <code>.drectve</code> carries what the linker needs, as text. Three different mechanisms, one shared property: <strong>the information is not in the program.</strong> Two of the three are consumed and forgotten, and the third survives only as a runtime behaviour.</p>
                <p>That is the natural companion to <a href="/courses/coff/lessons/coff-section-table">the section characteristics</a>, which taught that the flags are instructions rather than descriptions. This module found the three cases where the instruction is not "put this at this address" but something else entirely, and the flag that carries it in each case: <code>MEM_DISCARDABLE</code> and <code>LNK_REMOVE</code> for compiler and linker scratch, <code>LNK_COMDAT</code> for the deduplication contract, and <code>LNK_INFO</code> for this one. <strong>All four are one-byte fields, and all four change what the linker does rather than what the program contains.</strong></p>
                <p>The <a href="/courses/coff/lessons/coff-map-files">map files concept</a> is what made this module's claims checkable. Every discard observed here &mdash; <code>.debug$S</code>, <code>.llvm_addrsig</code>, and now <code>.drectve</code> &mdash; is a row in a map file, and every one of them was confirmed by a controlled comparison against an object built without the cause. That is the general pattern this course has tried to teach from the beginning: a flag in a header is a claim about what a tool will do, and the only way to know whether the claim is true is to run the tool and look.</p>
                <p>What remains in the COFF format is enumerated with reasons in <code>courses/coff/research.md</code>: import libraries and the short-import format, which need a <code>dlltool</code> this machine does not have; MSVC's incremental linking and LTCG, which need an MSVC toolchain; archives as link inputs, because GNU ld's PE mode will not read <code>ar</code>; and reading a bigobj, because no implementation exists anywhere on this machine. None of those is unwritten for want of effort, and each is blocked on something specific and nameable.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-weak-externals">Previous: Weak Externals</a></span>
                <span><a href="/courses/coff">Back to course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
