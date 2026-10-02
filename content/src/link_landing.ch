// Static Linking and Linker Scripts — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_link_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Static Linking and Linker Scripts — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    // THE PRE-PAINT THEME.  This landing page calls render_lesson_nav, which
    // passes lesson=true and therefore skips the theme script -- correct for a
    // LESSON, whose palette is hardcoded light, but wrong here: this is a
    // course landing page and a reader who chose dark, or whose OS is dark,
    // should not get a flash of light before the page settles.
    //
    // Two lines, and the alternative is to change what these 28 pages call --
    // a layout change across the whole collection that is worth doing on its
    // own and is not what the flash report asked for.
    render_theme_boot_js(&mut page, false)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson link-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>Static Linking and Linker Scripts</h1>
            <div class="lesson-meta">10 concepts &middot; 4 modules &middot; 221 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>Every link you have ever run was driven by a program. It is 276 lines long, it ships as text, and the linker will print it for you if you ask. <strong>Nobody teaches it, because it looks like configuration rather than code &mdash; and that is exactly why it is worth a course.</strong></p>
                <p>It follows the <a href="/courses/obj">Object Files</a> course, which established what a relocation record <em>is</em>; the <a href="/courses/sym">Symbol Resolution</a> course, which established who decides what a name means; and the <a href="/courses/reloc">Relocations, PIC and PIE</a> course, which ended by writing a relocation applier that deliberately refused to decide the layout. <strong>This course is that refusal, answered.</strong> Ten concepts, in four modules:</p>
                <div class="formula">
  MODULE 1  The Script You Already Use
            ld --verbose, 276 lines, and a round trip
            that is byte-identical only when the flags agree
            the eight constructs, in the order they run
            first-match-wins, in four cells, and the
            hot/cold partition it exists for

  MODULE 2  Placing Things
            the dot, ALIGN, SIZEOF, and SEGMENT_START
            returning its SECOND argument
            MEMORY as a budget, and overflow as an error
            PHDRS by hand, and -T silently making your
            binary non-PIE

  MODULE 3  Roots and Selection
            --gc-sections as a graph walk, and why
            inlining changes the answer
            the five sections even the default script
            guesses at, and the flag that admits it

  MODULE 4  Static, and Build One
            52x the size, and the e_type the script
            followed
            write one, verify it, run it
</div>
            </div>

            <div class="unit unit-example">
                <h2>Every number here was measured</h2>
                <p>The toolchain was checked first, and its limits are stated up front: <strong>GNU ld 2.46 (bfd only &mdash; no gold and no lld), clang 21.1.8, binutils 2.46, glibc 2.43, x86-64 Linux.</strong> <code>ld --verbose</code> is a GNU ld feature, and nothing here depends on gold or lld.</p>
                <p>All findings are reproducible from one script, and a 124-check harness asserts every load-bearing claim &mdash; including two that exist only because the harness caught this course being wrong:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/link/assets/samples
$ ./build_samples.sh
$ python3 crosscheck.py
  ALL 124 CHECKS PASS
$ python3 linklab.py tour
  ...
  Every step verified.
</pre>
                </div>
                <p>The course ends with something you can run. <code>linklab.py</code> is a driver that writes linker scripts, runs the linker with them, and <strong>verifies the result rather than assuming it worked</strong> &mdash; twenty checks across five subcommands, each ending in <code>PASS</code> or <code>FAIL</code>. It needs nothing but a compiler and <code>ld</code>.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Start here</h2>
                <p><a href="/courses/link/lessons/link-default-script"><strong>The Program That Placed Your Binary</strong></a> &mdash; 22 min. <code>ld --verbose</code>, 276 lines, and the round trip. If you take one idea from this course, take that one: <strong>the layout decision is source, it is 276 lines, and you can read it in one command.</strong></p>
                <p>If you have finished the Relocations course, start with <a href="/courses/link/lessons/link-location-counter">The Location Counter</a>, which answers the note in that course&rsquo;s applier about the layout being somebody else&rsquo;s problem.</p>
                <p>If you only want the practical workflow, go to <a href="/courses/link/lessons/link-write-script">Writing One Yourself</a>.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What this course deliberately does not claim</h2>
                <p>Three things, and <strong>two claims from this course&rsquo;s own first drafts were retracted</strong> rather than quietly corrected. Both retractions are on this page.</p>
                <p><strong>Retracted: the round trip is byte-identical.</strong> The first measurement compared <em>sizes</em>, found them equal at 15912, and concluded the saved script reproduces ld&rsquo;s output. Comparing <em>files</em> showed the two PIE builds differ at byte 16, which is <code>e_type</code>: ld&rsquo;s own default emits <code>ET_DYN</code> on this toolchain and the script emits <code>ET_EXEC</code>. The honest claim is narrower: the round trip is byte-identical <em>exactly when the flags and the script agree about the code model</em>.</p>
                <p><strong>Retracted: <code>/DISCARD/</code> beats rule order.</strong> It does not; it is plain first-match-wins, and the four-cell experiment proves it. The original experiment was broken rather than the model &mdash; two chained <code>str.replace()</code> calls, and in the file that &ldquo;proved&rdquo; it the first had not applied, so the cell named &ldquo;keep first&rdquo; contained no keep rule at all. <strong>A <code>replace()</code> that matches nothing returns the text unchanged and reports success</strong>, which is indistinguishable from a linker obeying you. The lesson is now asserted in the build script and taught in <a href="/courses/link/lessons/link-order">Which Rule Wins</a>: when an experiment about a build tool surprises you, the first hypothesis is that your edit did not apply.</p>
                <p><strong>Not claimed: that <code>MEMORY</code> attributes drive the segment flags.</strong> The documentation reads that way and this course&rsquo;s first draft asserted it. Measured, they are inert in GNU ld 2.46: <code>.text</code> in a <code>(w)</code> region produced the same <code>R E</code> segment as <code>(rx)</code>, with no diagnostic either way. The flags came from the section. <a href="/courses/link/lessons/link-memory-regions">The concept</a> shows the measurement and the correction side by side rather than only the corrected version.</p>
                <p>Also not claimed: anything about lld or gold, which have different scripts; anything about real hardware, since the <code>MEMORY</code> and <code>PHDRS</code> experiments run on a hosted target with a loader present and prove the mechanism rather than a bootable board; and that a static glibc binary works for name resolution &mdash; <a href="/courses/link/lessons/link-static-real">that concept</a> explains the architectural reason it may not, and this course does not pretend to have measured both cases.</p>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
