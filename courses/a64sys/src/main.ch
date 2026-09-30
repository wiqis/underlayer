// The AArch64 Machine: Modes, Memory and Faults -- build entry point.
// Renders the landing page and all 6 concept pages to output/.
//
// Concept order, and the reason for it.
//
// 1. `a64-syscall` first, because it is the cheapest possible example of the
//    distinction the whole course rests on: a constant in an instruction and
//    a value in a register look identical in the assembly and are different
//    kinds of claim.  It is also the only concept whose subject is
//    measurable in something a compiler actually does, so it establishes the
//    method before the reader has to trust it.
// 2. `a64-exceptions` second, because the register layout is the interface
//    between a 32-bit field and everything the machine can go wrong with, and
//    because it is where the QUOTED half of the course is largest -- which is
//    why it is second and not last.
// 3. `a64-interrupts` third, because it is the first concept whose largest
//    result is an ABSENCE: four alignment directives and four times no
//    diagnostic.  A reader who has just read two pages of measured numbers
//    needs to meet the silence before the next page of them.
// 4. `a64-virtual` fourth, because the regime is the thing a fault came from
//    and because it is where a quoted field width kills a plausible-looking
//    number -- the first draft of this course's own table.
// 5. `a64-pagetables` fifth, because it is the hinge to the ELF, relocation
//    and linker courses, and because it has the most measured content in the
//    course.  It comes after the regime because the block size FOLLOWS from
//    the address-space size, and reading it the other way round produces the
//    menu mistake that is retraction R13.
// 6. `a64-evidence` last, for the same reason `a64-verify` is last in the
//    encoding course and `a64-unwind` is last in the ABI course: it is the
//    part that says which of the other five you are allowed to believe, and
//    the part where the artifact has to poison its own cross-check before its
//    100% means anything.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering The AArch64 Machine: Modes, Memory and Faults pages...\n")

    var html = underlayer_content::render_a64sys_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Modes -- getting in, getting out, being interrupted
    html = underlayer_content::render_a64_syscall()
    fs::write_text_file("output/a64-syscall.html", html.data() as *u8, html.size())
    printf("  -> a64-syscall.html\n")

    html = underlayer_content::render_a64_exceptions()
    fs::write_text_file("output/a64-exceptions.html", html.data() as *u8, html.size())
    printf("  -> a64-exceptions.html\n")

    html = underlayer_content::render_a64_interrupts()
    fs::write_text_file("output/a64-interrupts.html", html.data() as *u8, html.size())
    printf("  -> a64-interrupts.html\n")

    // Module 2: The Memory -- two regimes, four levels, and the linker
    html = underlayer_content::render_a64_virtual()
    fs::write_text_file("output/a64-virtual.html", html.data() as *u8, html.size())
    printf("  -> a64-virtual.html\n")

    html = underlayer_content::render_a64_pagetables()
    fs::write_text_file("output/a64-pagetables.html", html.data() as *u8, html.size())
    printf("  -> a64-pagetables.html\n")

    // The artifact, and the concept that makes the other five trustworthy.
    html = underlayer_content::render_a64_evidence()
    fs::write_text_file("output/a64-evidence.html", html.data() as *u8, html.size())
    printf("  -> a64-evidence.html\n")

    printf("Done: 6 concepts + landing page\n")
    return 0
}
