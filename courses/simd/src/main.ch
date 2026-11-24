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
    course_writer::ensure_output()
    println(`Rendering SIMD and Vector Processing pages...`)

    var html = underlayer_content::render_simd_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Lane
    html = underlayer_content::render_simd_width()
    course_writer::write_page("output/simd-width.html", &html)
    println(`  -> simd-width.html`)

    html = underlayer_content::render_simd_compiler()
    course_writer::write_page("output/simd-compiler.html", &html)
    println(`  -> simd-compiler.html`)

    // Module 2: What the Instructions Do
    html = underlayer_content::render_simd_shapes()
    course_writer::write_page("output/simd-shapes.html", &html)
    println(`  -> simd-shapes.html`)

    html = underlayer_content::render_simd_reduce()
    course_writer::write_page("output/simd-reduce.html", &html)
    println(`  -> simd-reduce.html`)

    // Module 3: Where It Costs
    html = underlayer_content::render_simd_boundaries()
    course_writer::write_page("output/simd-boundaries.html", &html)
    println(`  -> simd-boundaries.html`)

    html = underlayer_content::render_simd_three()
    course_writer::write_page("output/simd-three.html", &html)
    println(`  -> simd-three.html`)

    // Module 4: The Artifact
    html = underlayer_content::render_simd_harness()
    course_writer::write_page("output/simd-harness.html", &html)
    println(`  -> simd-harness.html`)

    println(`Done: 7 concepts + landing page`)
    return 0
}
