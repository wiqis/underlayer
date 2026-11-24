// How a CPU Executes Instructions â€” build entry point.
// Renders all 6 concept pages plus the landing page to output/.
//
// Concept order: the instrument first, because every other number in this
// course is produced by it and the instrument's own noise floor decides what
// may be claimed. Then latency and throughput, then what a dependency is and
// what the front end does, then the two concepts about the limits of what
// could be measured at all.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering How a CPU Executes Instructions pages...`)

    var html = underlayer_content::render_exe_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Instrument
    html = underlayer_content::render_exe_instrument()
    course_writer::write_page("output/exe-instrument.html", &html)
    println(`  -> exe-instrument.html`)

    html = underlayer_content::render_exe_latency()
    course_writer::write_page("output/exe-latency.html", &html)
    println(`  -> exe-latency.html`)

    // Module 2: Dependencies and the Front End
    html = underlayer_content::render_exe_deps()
    course_writer::write_page("output/exe-deps.html", &html)
    println(`  -> exe-deps.html`)

    html = underlayer_content::render_exe_frontend()
    course_writer::write_page("output/exe-frontend.html", &html)
    println(`  -> exe-frontend.html`)

    // Module 3: Speculation and Its Limits
    html = underlayer_content::render_exe_speculate()
    course_writer::write_page("output/exe-speculate.html", &html)
    println(`  -> exe-speculate.html`)

    html = underlayer_content::render_exe_verify()
    course_writer::write_page("output/exe-verify.html", &html)
    println(`  -> exe-verify.html`)

    println(`Done: 6 concepts + landing page`)
    return 0
}
