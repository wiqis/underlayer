// Relocations, PIC and PIE — build entry point.
// Renders all 9 concept pages plus the landing page to output/.
//
// Concept order is the dependency chain: why the vocabulary exists at all,
// then what position independence is and what it costs, then the two ways it
// fails, then building the thing that consumes a relocation.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Relocations/PIC/PIE pages...\n")

    var html = underlayer_content::render_reloc_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Vocabulary
    html = underlayer_content::render_reloc_arch_contrast()
    fs::write_text_file("output/reloc-arch-contrast.html", html.data() as *u8, html.size())
    printf("  -> reloc-arch-contrast.html\n")

    html = underlayer_content::render_reloc_why_so_many()
    fs::write_text_file("output/reloc-why-so-many.html", html.data() as *u8, html.size())
    printf("  -> reloc-why-so-many.html\n")

    html = underlayer_content::render_reloc_encoding_limits()
    fs::write_text_file("output/reloc-encoding-limits.html", html.data() as *u8, html.size())
    printf("  -> reloc-encoding-limits.html\n")

    // Module 2: Position Independent Executables
    html = underlayer_content::render_pie_flags()
    fs::write_text_file("output/pie-flags.html", html.data() as *u8, html.size())
    printf("  -> pie-flags.html\n")

    html = underlayer_content::render_pie_randomize()
    fs::write_text_file("output/pie-randomize.html", html.data() as *u8, html.size())
    printf("  -> pie-randomize.html\n")

    html = underlayer_content::render_pie_cost()
    fs::write_text_file("output/pie-cost.html", html.data() as *u8, html.size())
    printf("  -> pie-cost.html\n")

    // Module 3: How It Fails
    html = underlayer_content::render_pic_violation()
    fs::write_text_file("output/pic-violation.html", html.data() as *u8, html.size())
    printf("  -> pic-violation.html\n")

    html = underlayer_content::render_tls_model()
    fs::write_text_file("output/tls-model.html", html.data() as *u8, html.size())
    printf("  -> tls-model.html\n")

    // Module 4: Applying One
    html = underlayer_content::render_reloc_apply()
    fs::write_text_file("output/reloc-apply.html", html.data() as *u8, html.size())
    printf("  -> reloc-apply.html\n")

    printf("Done: 9 concepts + landing page\n")
    return 0
}
