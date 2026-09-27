// How a CPU Executes Instructions — build entry point.
// Renders all 6 concept pages plus the landing page to output/.
//
// Concept order: the instrument first, because every other number in this
// course is produced by it and the instrument's own noise floor decides what
// may be claimed. Then latency and throughput, then what a dependency is and
// what the front end does, then the two concepts about the limits of what
// could be measured at all.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering How a CPU Executes Instructions pages...\n")

    var html = underlayer_content::render_exe_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Instrument
    html = underlayer_content::render_exe_instrument()
    fs::write_text_file("output/exe-instrument.html", html.data() as *u8, html.size())
    printf("  -> exe-instrument.html\n")

    html = underlayer_content::render_exe_latency()
    fs::write_text_file("output/exe-latency.html", html.data() as *u8, html.size())
    printf("  -> exe-latency.html\n")

    // Module 2: Dependencies and the Front End
    html = underlayer_content::render_exe_deps()
    fs::write_text_file("output/exe-deps.html", html.data() as *u8, html.size())
    printf("  -> exe-deps.html\n")

    html = underlayer_content::render_exe_frontend()
    fs::write_text_file("output/exe-frontend.html", html.data() as *u8, html.size())
    printf("  -> exe-frontend.html\n")

    // Module 3: Speculation and Its Limits
    html = underlayer_content::render_exe_speculate()
    fs::write_text_file("output/exe-speculate.html", html.data() as *u8, html.size())
    printf("  -> exe-speculate.html\n")

    html = underlayer_content::render_exe_verify()
    fs::write_text_file("output/exe-verify.html", html.data() as *u8, html.size())
    printf("  -> exe-verify.html\n")

    printf("Done: 6 concepts + landing page\n")
    return 0
}
