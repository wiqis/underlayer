// Static Linking and Linker Scripts â€” build entry point.
// Renders all 10 concept pages plus the landing page to output/.
//
// Concept order is the dependency chain: first read the script you are already
// using, then learn to place things with it, then what it keeps and drops, and
// finally build one.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Static Linking pages...`)

    var html = underlayer_content::render_link_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Script You Already Use
    html = underlayer_content::render_link_default_script()
    course_writer::write_page("output/link-default-script.html", &html)
    println(`  -> link-default-script.html`)

    html = underlayer_content::render_link_script_language()
    course_writer::write_page("output/link-script-language.html", &html)
    println(`  -> link-script-language.html`)

    html = underlayer_content::render_link_order()
    course_writer::write_page("output/link-order.html", &html)
    println(`  -> link-order.html`)

    // Module 2: Placing Things
    html = underlayer_content::render_link_location_counter()
    course_writer::write_page("output/link-location-counter.html", &html)
    println(`  -> link-location-counter.html`)

    html = underlayer_content::render_link_memory_regions()
    course_writer::write_page("output/link-memory-regions.html", &html)
    println(`  -> link-memory-regions.html`)

    html = underlayer_content::render_link_phdrs()
    course_writer::write_page("output/link-phdrs.html", &html)
    println(`  -> link-phdrs.html`)

    // Module 3: Roots and Selection
    html = underlayer_content::render_link_keep_gc()
    course_writer::write_page("output/link-keep-gc.html", &html)
    println(`  -> link-keep-gc.html`)

    html = underlayer_content::render_link_orphans()
    course_writer::write_page("output/link-orphans.html", &html)
    println(`  -> link-orphans.html`)

    // Module 4: Static, and Build One
    html = underlayer_content::render_link_static_real()
    course_writer::write_page("output/link-static-real.html", &html)
    println(`  -> link-static-real.html`)

    html = underlayer_content::render_link_write_script()
    course_writer::write_page("output/link-write-script.html", &html)
    println(`  -> link-write-script.html`)

    println(`Done: 10 concepts + landing page`)
    return 0
}
