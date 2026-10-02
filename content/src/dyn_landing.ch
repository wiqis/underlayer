// Dynamic Linking and Shared Libraries — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dyn_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Dynamic Linking and Shared Libraries — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson dyn-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>Dynamic Linking and Shared Libraries</h1>
            <div class="lesson-meta">10 concepts &middot; 4 modules &middot; 224 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>You have read about <code>DT_NEEDED</code> and you know that search paths exist. This course is about the other half, and it is the half with all the behaviour in it: <strong>once the loader has found every file, it has an ordered list, and every undefined symbol in your program is answered by searching that list and taking the first match.</strong></p>
                <p>It follows the <a href="/courses/obj">Object Files</a> course, which established what a shared object <em>is</em>; the <a href="/courses/sym">Symbol Resolution</a> course, which covered the PLT, the hash tables and versioned symbols; the <a href="/courses/reloc">Relocations, PIC and PIE</a> course, which measured the cost of position independence and the one relocation that has to call a function; and the <a href="/courses/link">Static Linking</a> course, which made <code>ld --verbose</code> into a file you can edit. <strong>None of them covered the scope, and it is the central mechanism.</strong> Ten concepts, in four modules:</p>
                <div class="formula">
  MODULE 1  The Scope
            the ordered list every undefined symbol is
            answered from
            interposition: the executable's definition
            wins, including inside libraries
            breadth-first or depth-first, measured from
            the loader's own load order

  MODULE 2  Building a Library
            what ends up in .dynsym, and the four
            commands that decide it
            -fvisibility=hidden, version scripts, and
            the flag that breaks every caller
            -Bsymbolic: one instruction, and the
            precise thing its name hides

  MODULE 3  Loading at Run Time
            dlopen, dlsym, and why RTLD_LOCAL is 0
            lazy, eager, and the .got.plt section that
            disappears
            where the thread blocks come from

  MODULE 4  Rebuild It
            read DT_NEEDED, walk it breadth-first,
            resolve a symbol, check against the real loader
</div>
            </div>

            <div class="unit unit-example">
                <h2>Every number here was measured</h2>
                <p>The toolchain was checked first, and its limits are stated up front: <strong>GNU ld 2.46 (bfd only), clang 21.1.8, glibc and its loader 2.43, binutils 2.46, x86-64 Linux, PIE by default.</strong></p>
                <p>The instrument this course relies on is unusual and worth naming: <strong><code>LD_DEBUG=bindings</code> makes glibc&rsquo;s loader print every symbol binding it makes</strong>, and <code>LD_DEBUG=libs</code> prints every library it searches for, in order. Every claim below about what the loader <em>does</em> is that output, not a description of the documentation.</p>
                <div class="hex-dump">
                    <pre>$ cd courses/dyn/assets/samples
$ ./build_samples.sh
$ python3 crosscheck.py
  ALL 119 CHECKS PASS
$ python3 dynscope.py tour
  ...
  Every step verified.
</pre>
                </div>
                <p>The course ends with something you can run. <code>dynscope.py</code> rebuilds the global scope from the files and resolves symbols the way <code>ld.so</code> does, with no loader involved &mdash; then <strong>cross-checks every answer against <code>LD_DEBUG=bindings</code></strong>, so it is tested against the implementation it is modelling rather than against itself.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Start here</h2>
                <p><a href="/courses/dyn/lessons/dyn-scope"><strong>The Global Scope</strong></a> &mdash; 24 min. The ordered list, and how the loader builds it. If you take one idea from this course, take that one: <strong>dynamic linking is a search, and everything else is a variation on which entry wins.</strong></p>
                <p>If you have finished the Relocations course, start with <a href="/courses/dyn/lessons/dyn-interpose">Interposition</a>, which is the consequence of that search that surprises everybody, including the loader&rsquo;s own authors.</p>
                <p>If you only want the practical material, go to <a href="/courses/dyn/lessons/dyn-dlopen">dlopen, dlsym, and the Mode Bits</a>.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What this course deliberately does not claim</h2>
                <p>Three things, and <strong>one claim from this course&rsquo;s own drafts was retracted</strong> rather than quietly corrected.</p>
                <p><strong>No performance claim for lazy versus eager binding.</strong> The structural facts are exact and reproducible: the <code>.plt</code> is byte-identical, <code>.got.plt</code> disappears under <code>-z now</code>, and the loader makes <em>exactly one</em> binding in all three configurations. The wall-clock is not claimed: a two-million-call microbenchmark on this machine gave 5.1, 3.8 and 4.5 ns/call across the three, which is noise. <strong>A number that cannot be defended is worse than no number</strong>, and the <a href="/courses/reloc/lessons/pie-cost">Relocations course</a> declined a similar claim for the same reason.</p>
                <p><strong>Retracted: that <code>--as-needed</code> dropped <code>liba.so</code> from the second build.</strong> It did not &mdash; <code>liba.so</code> is in both <code>DT_NEEDED</code> lists. The first draft of <a href="/courses/dyn/lessons/dyn-order-runtime">the breadth-first concept</a> told a tidier and wrong story about the link-order experiment. The real mechanism is the direct one: <code>DT_NEEDED</code> order follows the link line order, and the shim library precedes <code>liba.so</code> in both builds &mdash; by three positions in one and by one in the other. <strong>Move <code>-la</code> up one place and the answer changes, with identical source and identical flags.</strong> The correction is in the concept, in the build script, and in two of the crosscheck&rsquo;s assertions.</p>
                <p><strong>Not claimed: the static-TLS surplus threshold.</strong> The mechanism is real and is the subject of <a href="/courses/dyn/lessons/dyn-tls-block">Where the Thread Blocks Come From</a>, and the code side of it was measured by the Relocations course. The attempt to measure the <em>threshold</em> here &mdash; thirty-two dlopen-able libraries each carrying 256 bytes of thread-local storage &mdash; <strong>failed to link at all</strong>, because <code>--as-needed</code> dropped every one of them with nothing referencing them. The exercise is left to the reader, with the failure written down, because <strong>a measurement that requires the thing under test to be present has a failure mode that looks exactly like success.</strong></p>
                <p>Also not claimed: that <code>dlclose</code> unmaps anything, a timing comparison with lld or gold, and anything about Mach-O&rsquo;s two-level namespace &mdash; the object-files course has measured Mach-O object files, and this course has no Mach-O <code>dyld</code> to measure.</p>
            </div>
        </div>
    

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
