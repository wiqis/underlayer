// The Memory Hierarchy â€” build entry point.
// Renders all 8 concept pages plus the landing page to output/.
//
// Concept order: the instrument first, because every number in this course is
// produced by it and its noise floor decides what may be claimed. Then the two
// kinds of memory measurement, which is the trap the instrument exists to
// avoid. Then the hierarchy as a curve and the hierarchy as a set conflict,
// which are the same hardware seen from two sides. Then what a page and a
// store cost, which is where a program's own addresses start to matter. Then
// sharing, which is the one coherence-adjacent effect this machine can measure
// without a PMU. And last the harness, because the claim this course refuses to
// make is part of the course.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering The Memory Hierarchy pages...`)

    var html = underlayer_content::render_mem_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Instrument
    html = underlayer_content::render_mem_instrument()
    course_writer::write_page("output/mem-instrument.html", &html)
    println(`  -> mem-instrument.html`)

    html = underlayer_content::render_mem_latency()
    course_writer::write_page("output/mem-latency.html", &html)
    println(`  -> mem-latency.html`)

    // Module 2: The Hierarchy
    html = underlayer_content::render_mem_hierarchy()
    course_writer::write_page("output/mem-hierarchy.html", &html)
    println(`  -> mem-hierarchy.html`)

    html = underlayer_content::render_mem_associativity()
    course_writer::write_page("output/mem-associativity.html", &html)
    println(`  -> mem-associativity.html`)

    // Module 3: What a Page and a Store Cost
    html = underlayer_content::render_mem_translation()
    course_writer::write_page("output/mem-translation.html", &html)
    println(`  -> mem-translation.html`)

    html = underlayer_content::render_mem_writes()
    course_writer::write_page("output/mem-writes.html", &html)
    println(`  -> mem-writes.html`)

    // Module 4: Sharing, and Verification
    html = underlayer_content::render_mem_sharing()
    course_writer::write_page("output/mem-sharing.html", &html)
    println(`  -> mem-sharing.html`)

    html = underlayer_content::render_mem_verify()
    course_writer::write_page("output/mem-verify.html", &html)
    println(`  -> mem-verify.html`)

    println(`Done: 8 concepts + landing page`)
    return 0
}
