// Symbol Resolution and Symbol Tables — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_sym_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Symbol Resolution and Symbol Tables — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson sym-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>Symbol Resolution and Symbol Tables</h1>
            <div class="lesson-meta">12 concepts &middot; 4 modules &middot; 253 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>You have written <code>answer()</code> in one file and called it from another, and never had to say where it came from. This course is about the machinery that makes that work &mdash; and about the several different questions hiding behind the phrase &ldquo;resolve this symbol.&rdquo;</p>
                <p>It follows the <a href="/courses/obj">Object Files</a> course, which established what a relocation and a symbol table <em>are</em>. This one is about what happens when several files are put together and every name has to be given exactly one meaning. Twelve concepts, in four modules:</p>
                <div class="formula">
  MODULE 1  What a Symbol Is
            a name is a question, not a thing
            binding: LOCAL, GLOBAL, WEAK
            visibility: and why two of its four values are
                        not stored in the visibility field

  MODULE 2  The Resolution Algorithm
            the demand-driven pass, left to right
            order, archives, and the map file
            multiple definition, and the storage class that
            made the same source legal for thirty years

  MODULE 3  Resolution at Runtime
            the two hash tables, and one that is not in the
            order you would guess
            the PLT, six instructions at a time
            eager binding: a flag that changes no code
            GLOB_DAT vs COPY, decided by a compile flag

  MODULE 4  Versions and Invented Symbols
            three tables, a parent chain, a reused hash
            the symbols the linker makes up
</div>
            </div>

            <div class="unit unit-example">
                <h2>Every number here was measured</h2>
                <p>Nothing in this course is quoted from a specification and trusted. The toolchain was checked first, and its limits are stated up front: <strong>GNU ld 2.46 (bfd only, no gold and no lld), LLVM 21, gcc 15.2, glibc 2.43, x86-64 Linux.</strong> There is no Mach-O linker and no Mach-O runtime on this machine, so the dynamic half of this course is ELF-only and says so where it matters.</p>
                <p>All 20 findings are reproducible from one script, and an 84-check harness asserts every load-bearing claim:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/sym/assets/samples
$ ./build_samples.sh
$ python3 crosscheck.py
  ALL 84 CHECKS PASS
</pre>
                </div>
                <p>Two of those checks exist because the harness caught an over-broad claim in this course&rsquo;s own text during writing, which is the argument for having it. It also caught a false invariant I had asserted about <code>.gnu.hash</code> bucket ordering &mdash; real files violate it, so the claim was deleted rather than the check.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Start here</h2>
                <p><a href="/courses/sym/lessons/sym-intro"><strong>A Name Is Not a Symbol</strong></a> &mdash; 16 min. The frame for the whole course: a linker is asked two questions, not one, and almost every symbol concept answers exactly one of them.</p>
                <p>If you are coming from the <a href="/courses/obj">Object Files</a> course, start with <a href="/courses/sym/lessons/sym-binding">Binding, and the Two Tables</a>, which fills in the meaning of the <code>st_info</code> nibble you decoded there.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What this course deliberately does not claim</h2>
                <p>Two things, because a course that overclaims is worse than one that is short.</p>
                <p><strong>No copy-relocation divergence bug.</strong> The familiar story is that <code>R_X86_64_COPY</code> gives the executable and the library two copies that can drift apart. We built that case three ways on this machine &mdash; one library, two referencing libraries plus a definer, both code models &mdash; and all six values agreed every time. The loader redirects the library&rsquo;s references to the program&rsquo;s copy, so there is one storage under two names. <a href="/courses/sym/lessons/sym-copy-reloc">Who Owns the Storage</a> teaches the mechanism and declines the bug.</p>
                <p><strong>No Mach-O two-level namespace.</strong> There is no Mach-O linker on this machine to measure with. The object files course has measured Mach-O <em>object</em> files; this course has no Mach-O <em>linker</em> to measure, and says so rather than describing a mechanism it cannot demonstrate.</p>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
