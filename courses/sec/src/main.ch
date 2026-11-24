// Executable Security and Hardening â€” build entry point.
// Renders all 7 concept pages plus the landing page to output/.
//
// Concept order: the defaults first, because the compiler disagreement is the
// argument for the course; then the two features that leave a trace in the
// file's geometry; then the two that are about permissions; then the reader.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Executable Security pages...`)

    var html = underlayer_content::render_sec_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Defaults
    html = underlayer_content::render_sec_defaults()
    course_writer::write_page("output/sec-defaults.html", &html)
    println(`  -> sec-defaults.html`)

    html = underlayer_content::render_sec_canary()
    course_writer::write_page("output/sec-canary.html", &html)
    println(`  -> sec-canary.html`)

    // Module 2: The GOT
    html = underlayer_content::render_sec_relro()
    course_writer::write_page("output/sec-relro.html", &html)
    println(`  -> sec-relro.html`)

    html = underlayer_content::render_sec_fortify()
    course_writer::write_page("output/sec-fortify.html", &html)
    println(`  -> sec-fortify.html`)

    // Module 3: Permissions
    html = underlayer_content::render_sec_wx()
    course_writer::write_page("output/sec-wx.html", &html)
    println(`  -> sec-wx.html`)

    html = underlayer_content::render_sec_cet()
    course_writer::write_page("output/sec-cet.html", &html)
    println(`  -> sec-cet.html`)

    // Module 4: Read It Yourself
    html = underlayer_content::render_sec_posture()
    course_writer::write_page("output/sec-posture.html", &html)
    println(`  -> sec-posture.html`)

    println(`Done: 7 concepts + landing page`)
    return 0
}
