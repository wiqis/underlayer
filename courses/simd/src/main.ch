// SIMD and Vector Processing -- build entry point.
// Renders all 7 concept pages plus the landing page to output/.
//
// Concept order: the register first, because every number in this course is a
// claim about a THING WITH LANES IN IT and "lane" was used as a known quantity
// by the execution course without ever being defined.  Then the compiler,
// because the measurement that the compiler beats hand-written intrinsics is
// the one that changed this course's mind about what it was for.  Then the
// instruction shapes, which are elementwise and independent and say nothing
// about each other.  Then the reduction, which is the one place where lanes
// talk to each other and the only place in the course where a vector loop
// loses.  Then the boundaries, where the width gets spent.  Then the other two
// architectures, quoted.  And last the harness, because the retractions are
// part of the course.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering SIMD and Vector Processing pages...\n")

    var html = underlayer_content::render_simd_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Lane
    html = underlayer_content::render_simd_width()
    fs::write_text_file("output/simd-width.html", html.data() as *u8, html.size())
    printf("  -> simd-width.html\n")

    html = underlayer_content::render_simd_compiler()
    fs::write_text_file("output/simd-compiler.html", html.data() as *u8, html.size())
    printf("  -> simd-compiler.html\n")

    // Module 2: What the Instructions Do
    html = underlayer_content::render_simd_shapes()
    fs::write_text_file("output/simd-shapes.html", html.data() as *u8, html.size())
    printf("  -> simd-shapes.html\n")

    html = underlayer_content::render_simd_reduce()
    fs::write_text_file("output/simd-reduce.html", html.data() as *u8, html.size())
    printf("  -> simd-reduce.html\n")

    // Module 3: Where It Costs
    html = underlayer_content::render_simd_boundaries()
    fs::write_text_file("output/simd-boundaries.html", html.data() as *u8, html.size())
    printf("  -> simd-boundaries.html\n")

    html = underlayer_content::render_simd_three()
    fs::write_text_file("output/simd-three.html", html.data() as *u8, html.size())
    printf("  -> simd-three.html\n")

    // Module 4: The Artifact
    html = underlayer_content::render_simd_harness()
    fs::write_text_file("output/simd-harness.html", html.data() as *u8, html.size())
    printf("  -> simd-harness.html\n")

    printf("Done: 7 concepts + landing page\n")
    return 0
}
