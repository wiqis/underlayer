// Relocations, PIC and PIE — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_reloc_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Relocations, PIC and PIE — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson reloc-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>Relocations, PIC and PIE</h1>
            <div class="lesson-meta">9 concepts &middot; 4 modules &middot; 195 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>You have seen a relocation in a hex dump. It has an offset, a type, a symbol and an addend, and it is usually four bytes of zeros. This course is about why that record is shaped the way it is, what the alternative shapes would have cost, and what happens when none of them fit.</p>
                <p>It follows the <a href="/courses/obj">Object Files</a> course, which established <em>what</em> a relocation record is, and the <a href="/courses/sym">Symbol Resolution</a> course, which established who resolves one. <strong>This one asks the question those two left open: why is there a <em>type</em> field at all?</strong> Nine concepts, in four modules:</p>
                <div class="formula">
  MODULE 1  The Vocabulary
            the same source on two architectures: one
            relocation, or two
            the ~40 x86-64 types, grouped by what they
            compute, and the 2003 accident inside one
            of their names
            reach, overflow, and a zero displacement

  MODULE 2  Position Independent Executables
            -fPIC against -pie, and the binary that is
            neither because they disagreed
            six runs, two builds, and a random base
            nine instructions against seventeen

  MODULE 3  How It Fails
            a failure class only PIC has, and the
            diagnostic that names the type and the fix
            four thread-local models, and the one
            relocation that has to CALL the loader

  MODULE 4  Applying One
            read a real object, apply its relocations
            at an address you choose, check the result
</div>
            </div>

            <div class="unit unit-example">
                <h2>Every number here was measured</h2>
                <p>The toolchain was checked first, and its limits are stated up front: <strong>GNU ld 2.46 (bfd only, no gold and no lld), LLVM 21.1.8, gcc 15.2, glibc 2.43, x86-64 Linux.</strong> There is no Mach-O linker and no AArch64 linker on this machine, so the AArch64 findings are about <em>object files and relocation vocabularies only</em> &mdash; never about running the code.</p>
                <p>All findings are reproducible from one script, and an 87-check harness asserts every load-bearing claim:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/reloc/assets/samples
$ ./build_samples.sh
$ python3 crosscheck.py
  ALL 87 CHECKS PASS
$ python3 apply_relocs.py
  all 3 relocations applied; 38 bytes of .text
</pre>
                </div>
                <p>The course ends with something you can run. <code>apply_relocs.py</code> is a complete relocation applier &mdash; no libraries, no <code>libelf</code> &mdash; that reads a real object file, places its sections at a base address you choose, applies every relocation, and refuses when a value does not fit. It is about 250 lines, and the part that matters is three.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Start here</h2>
                <p><a href="/courses/reloc/lessons/reloc-arch-contrast"><strong>One Relocation, or Two</strong></a> &mdash; 22 min. The same source compiled for x86-64 and for AArch64: one relocation per datum against two, and the AArch64 <em>type</em> encodes the access width. If you take one idea from this course, take that one &mdash; it is the reason a relocation table is a property of the target and not of your program.</p>
                <p>If you are coming from the <a href="/courses/obj">Object Files</a> course, start with <a href="/courses/reloc/lessons/reloc-why-so-many">Why There Are So Many Kinds</a>, which answers the question its <code>obj-relocations</code> concept had to leave open.</p>
                <p>If you have already read those and want the practical payoff, go straight to <a href="/courses/reloc/lessons/reloc-apply">Applying Them Yourself</a>.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What this course deliberately does not claim</h2>
                <p>Three things, because a course that overclaims is worse than one that is short. All three were measured, and in one case a claim was <em>retracted</em>.</p>
                <p><strong>No measured runtime cost of PIE against non-PIE.</strong> The <em>code</em> cost is exact &mdash; 9 instructions against 17, 6 bytes against 10 per reference, a 96-byte GOT for 8 globals. Wall-clock is not claimed, because it depends on the machine and a number I could not defend is worse than no number. The one effect that <em>would</em> argue for PIE on footprint grounds is kernel-dependent, and the landing page of that idea is marked as unmeasured rather than asserted.</p>
                <p><strong>No AArch64 execution.</strong> AArch64 objects are compiled and read, which is enough to establish the relocation-count and access-width findings. There is no aarch64 linker or runtime here, so nothing is claimed about running that code &mdash; only about what the object file says.</p>
                <p><strong>A retraction.</strong> The TLS finding was measured once, wrongly, and the wrong version is recorded. The claim was that <em>local-dynamic and initial-exec emit identical relocations</em>. It is not true: they differ. The first specimen made local-dynamic inapplicable (it only applies to a symbol in the same module) and an <code>-O1</code> constant-fold removed the module-local access entirely, so there was nothing left to distinguish them. <a href="/courses/reloc/lessons/tls-model">The TLS concept</a> teaches the corrected measurement, shows the wrong one, and explains the general lesson: <em>when two things measure as identical, the first hypothesis is that your optimiser deleted the difference</em>, not that they really are the same.</p>
                <p>One further limit is stated in the TLS concept rather than here, because it is narrow: forcing <code>local-dynamic</code> onto a cross-module symbol links without a diagnostic, and under a one-module test it even returned the right answer. <strong>We did not construct a case where it returns the wrong one</strong>, so the claim is that the misuse is latent and undetectable, not that it is broken.</p>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
