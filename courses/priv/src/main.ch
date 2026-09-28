// Exceptions, Privilege and Mode Changes -- build entry point.
// Renders all 8 concept pages plus the landing page to output/.
//
// Concept order: the gate table first, because it is the one structure the CPU
// consults on every change of mode and the one a user process can neither read
// nor write; then the vector numbers, because a number that is not defined is
// the most common way a reader of a manual is misled. Then the three doors
// into the kernel, which are not three spellings of one mechanism -- only two
// of them go through a gate at all. Then the convention, read out of the
// kernel's own bytes rather than out of a manual. Then the two things that
// make mode 3 what it is: the canonical hole, measured, and the error code as
// a data structure. Then the same idea under three architectures, because a
// course that says "ring 0" and stops is a course about one vendor. And last
// the harness, because the claim this course refuses to make is part of it.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Exceptions, Privilege and Mode Changes pages...\n")

    var html = underlayer_content::render_priv_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Table and the Numbers
    html = underlayer_content::render_priv_table()
    fs::write_text_file("output/priv-table.html", html.data() as *u8, html.size())
    printf("  -> priv-table.html\n")

    html = underlayer_content::render_priv_vectors()
    fs::write_text_file("output/priv-vectors.html", html.data() as *u8, html.size())
    printf("  -> priv-vectors.html\n")

    // Module 2: Three Doors
    html = underlayer_content::render_priv_doors()
    fs::write_text_file("output/priv-doors.html", html.data() as *u8, html.size())
    printf("  -> priv-doors.html\n")

    html = underlayer_content::render_priv_convention()
    fs::write_text_file("output/priv-convention.html", html.data() as *u8, html.size())
    printf("  -> priv-convention.html\n")

    // Module 3: What Mode 3 Is Made Of
    html = underlayer_content::render_priv_canonical()
    fs::write_text_file("output/priv-canonical.html", html.data() as *u8, html.size())
    printf("  -> priv-canonical.html\n")

    html = underlayer_content::render_priv_errorcode()
    fs::write_text_file("output/priv-errorcode.html", html.data() as *u8, html.size())
    printf("  -> priv-errorcode.html\n")

    html = underlayer_content::render_priv_three()
    fs::write_text_file("output/priv-three.html", html.data() as *u8, html.size())
    printf("  -> priv-three.html\n")

    // Module 4: The Artifact
    html = underlayer_content::render_priv_harness()
    fs::write_text_file("output/priv-harness.html", html.data() as *u8, html.size())
    printf("  -> priv-harness.html\n")

    printf("Done: 8 concepts + landing page\n")
    return 0
}
