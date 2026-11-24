// Symbol Resolution and Symbol Tables â€” build entry point.
// Renders all 12 concept pages plus the landing page to output/.
//
// Concept order is the dependency chain: what a symbol is, then how a linker
// resolves one, then how a loader does the same job with less information, then
// the two special cases (versions, and symbols the linker invents).

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Symbol Resolution pages...`)

    var html = underlayer_content::render_sym_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: What a Symbol Is
    html = underlayer_content::render_sym_intro()
    course_writer::write_page("output/sym-intro.html", &html)
    println(`  -> sym-intro.html`)

    html = underlayer_content::render_sym_binding()
    course_writer::write_page("output/sym-binding.html", &html)
    println(`  -> sym-binding.html`)

    html = underlayer_content::render_sym_visibility()
    course_writer::write_page("output/sym-visibility.html", &html)
    println(`  -> sym-visibility.html`)

    // Module 2: The Resolution Algorithm
    html = underlayer_content::render_sym_algorithm()
    course_writer::write_page("output/sym-algorithm.html", &html)
    println(`  -> sym-algorithm.html`)

    html = underlayer_content::render_sym_order()
    course_writer::write_page("output/sym-order.html", &html)
    println(`  -> sym-order.html`)

    html = underlayer_content::render_sym_duplicate()
    course_writer::write_page("output/sym-duplicate.html", &html)
    println(`  -> sym-duplicate.html`)

    // Module 3: Resolution at Runtime
    html = underlayer_content::render_sym_hash()
    course_writer::write_page("output/sym-hash.html", &html)
    println(`  -> sym-hash.html`)

    html = underlayer_content::render_sym_plt()
    course_writer::write_page("output/sym-plt.html", &html)
    println(`  -> sym-plt.html`)

    html = underlayer_content::render_sym_binding_time()
    course_writer::write_page("output/sym-binding-time.html", &html)
    println(`  -> sym-binding-time.html`)

    html = underlayer_content::render_sym_copy_reloc()
    course_writer::write_page("output/sym-copy-reloc.html", &html)
    println(`  -> sym-copy-reloc.html`)

    // Module 4: Versions and Invented Symbols
    html = underlayer_content::render_sym_version()
    course_writer::write_page("output/sym-version.html", &html)
    println(`  -> sym-version.html`)

    html = underlayer_content::render_sym_linker_defined()
    course_writer::write_page("output/sym-linker-defined.html", &html)
    println(`  -> sym-linker-defined.html`)

    println(`Done: 12 concepts + landing page`)
    return 0
}
