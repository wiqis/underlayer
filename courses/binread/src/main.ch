// E6 course build entry. Renders four concepts + the data-driven landing page.
// Every fact in these pages is traceable to courses/binread/assets/samples/*.txt.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Read a Binary by Hand (E6 paid first module)...`)

    // The landing page is data-driven by the server from this manifest, so no
    // static index.html is authored here (same contract as every other course).
    var html = underlayer_content::render_bin_magic()
    course_writer::write_page("output/bin-magic.html", &html)
    println(`  -> bin-magic.html`)

    html = underlayer_content::render_bin_header()
    course_writer::write_page("output/bin-header.html", &html)
    println(`  -> bin-header.html`)

    html = underlayer_content::render_bin_segments()
    course_writer::write_page("output/bin-segments.html", &html)
    println(`  -> bin-segments.html`)

    html = underlayer_content::render_bin_symbols()
    course_writer::write_page("output/bin-symbols.html", &html)
    println(`  -> bin-symbols.html`)

    println(`Done: 4 concepts + landing page`)
    return 0
}
