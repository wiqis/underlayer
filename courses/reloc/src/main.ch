// Relocations, PIC and PIE â€” build entry point.
// Renders all 9 concept pages plus the landing page to output/.
//
// Concept order is the dependency chain: why the vocabulary exists at all,
// then what position independence is and what it costs, then the two ways it
// fails, then building the thing that consumes a relocation.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Relocations/PIC/PIE pages...`)

    var html = underlayer_content::render_reloc_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Vocabulary
    html = underlayer_content::render_reloc_arch_contrast()
    course_writer::write_page("output/reloc-arch-contrast.html", &html)
    println(`  -> reloc-arch-contrast.html`)

    html = underlayer_content::render_reloc_why_so_many()
    course_writer::write_page("output/reloc-why-so-many.html", &html)
    println(`  -> reloc-why-so-many.html`)

    html = underlayer_content::render_reloc_encoding_limits()
    course_writer::write_page("output/reloc-encoding-limits.html", &html)
    println(`  -> reloc-encoding-limits.html`)

    // Module 2: Position Independent Executables
    html = underlayer_content::render_pie_flags()
    course_writer::write_page("output/pie-flags.html", &html)
    println(`  -> pie-flags.html`)

    html = underlayer_content::render_pie_randomize()
    course_writer::write_page("output/pie-randomize.html", &html)
    println(`  -> pie-randomize.html`)

    html = underlayer_content::render_pie_cost()
    course_writer::write_page("output/pie-cost.html", &html)
    println(`  -> pie-cost.html`)

    // Module 3: How It Fails
    html = underlayer_content::render_pic_violation()
    course_writer::write_page("output/pic-violation.html", &html)
    println(`  -> pic-violation.html`)

    html = underlayer_content::render_tls_model()
    course_writer::write_page("output/tls-model.html", &html)
    println(`  -> tls-model.html`)

    // Module 4: Applying One
    html = underlayer_content::render_reloc_apply()
    course_writer::write_page("output/reloc-apply.html", &html)
    println(`  -> reloc-apply.html`)

    println(`Done: 9 concepts + landing page`)
    return 0
}
