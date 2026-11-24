// Executable Images and OS Loading â€” build entry point.
// Renders all 6 concept pages plus the landing page to output/.
//
// Concept order: the handoff first (the auxv is the mechanism and nothing
// else in the course works without it), then how to read the values in it,
// then the address layout the kernel chose, then rebuild the reader.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Executable Images pages...`)

    var html = underlayer_content::render_img_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Handoff
    html = underlayer_content::render_img_auxv()
    course_writer::write_page("output/img-auxv.html", &html)
    println(`  -> img-auxv.html`)

    html = underlayer_content::render_img_stack()
    course_writer::write_page("output/img-stack.html", &html)
    println(`  -> img-stack.html`)

    // Module 2: Reading the Values
    html = underlayer_content::render_img_entries()
    course_writer::write_page("output/img-entries.html", &html)
    println(`  -> img-entries.html`)

    html = underlayer_content::render_img_vdso()
    course_writer::write_page("output/img-vdso.html", &html)
    println(`  -> img-vdso.html`)

    // Module 3: The Layout
    html = underlayer_content::render_img_place()
    course_writer::write_page("output/img-place.html", &html)
    println(`  -> img-place.html`)

    // Module 4: Rebuild It
    html = underlayer_content::render_img_walk()
    course_writer::write_page("output/img-walk.html", &html)
    println(`  -> img-walk.html`)

    println(`Done: 6 concepts + landing page`)
    return 0
}
