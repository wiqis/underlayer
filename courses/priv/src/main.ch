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
    course_writer::ensure_output()
    println(`Rendering Exceptions, Privilege and Mode Changes pages...`)

    var html = underlayer_content::render_priv_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Table and the Numbers
    html = underlayer_content::render_priv_table()
    course_writer::write_page("output/priv-table.html", &html)
    println(`  -> priv-table.html`)

    html = underlayer_content::render_priv_vectors()
    course_writer::write_page("output/priv-vectors.html", &html)
    println(`  -> priv-vectors.html`)

    // Module 2: Three Doors
    html = underlayer_content::render_priv_doors()
    course_writer::write_page("output/priv-doors.html", &html)
    println(`  -> priv-doors.html`)

    html = underlayer_content::render_priv_convention()
    course_writer::write_page("output/priv-convention.html", &html)
    println(`  -> priv-convention.html`)

    // Module 3: What Mode 3 Is Made Of
    html = underlayer_content::render_priv_canonical()
    course_writer::write_page("output/priv-canonical.html", &html)
    println(`  -> priv-canonical.html`)

    html = underlayer_content::render_priv_errorcode()
    course_writer::write_page("output/priv-errorcode.html", &html)
    println(`  -> priv-errorcode.html`)

    html = underlayer_content::render_priv_three()
    course_writer::write_page("output/priv-three.html", &html)
    println(`  -> priv-three.html`)

    // Module 4: The Artifact
    html = underlayer_content::render_priv_harness()
    course_writer::write_page("output/priv-harness.html", &html)
    println(`  -> priv-harness.html`)

    println(`Done: 8 concepts + landing page`)
    return 0
}
