// Symbol Resolution and Symbol Tables — build entry point.
// Renders all 12 concept pages plus the landing page to output/.
//
// Concept order is the dependency chain: what a symbol is, then how a linker
// resolves one, then how a loader does the same job with less information, then
// the two special cases (versions, and symbols the linker invents).

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Symbol Resolution pages...\n")

    var html = underlayer_content::render_sym_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: What a Symbol Is
    html = underlayer_content::render_sym_intro()
    fs::write_text_file("output/sym-intro.html", html.data() as *u8, html.size())
    printf("  -> sym-intro.html\n")

    html = underlayer_content::render_sym_binding()
    fs::write_text_file("output/sym-binding.html", html.data() as *u8, html.size())
    printf("  -> sym-binding.html\n")

    html = underlayer_content::render_sym_visibility()
    fs::write_text_file("output/sym-visibility.html", html.data() as *u8, html.size())
    printf("  -> sym-visibility.html\n")

    // Module 2: The Resolution Algorithm
    html = underlayer_content::render_sym_algorithm()
    fs::write_text_file("output/sym-algorithm.html", html.data() as *u8, html.size())
    printf("  -> sym-algorithm.html\n")

    html = underlayer_content::render_sym_order()
    fs::write_text_file("output/sym-order.html", html.data() as *u8, html.size())
    printf("  -> sym-order.html\n")

    html = underlayer_content::render_sym_duplicate()
    fs::write_text_file("output/sym-duplicate.html", html.data() as *u8, html.size())
    printf("  -> sym-duplicate.html\n")

    // Module 3: Resolution at Runtime
    html = underlayer_content::render_sym_hash()
    fs::write_text_file("output/sym-hash.html", html.data() as *u8, html.size())
    printf("  -> sym-hash.html\n")

    html = underlayer_content::render_sym_plt()
    fs::write_text_file("output/sym-plt.html", html.data() as *u8, html.size())
    printf("  -> sym-plt.html\n")

    html = underlayer_content::render_sym_binding_time()
    fs::write_text_file("output/sym-binding-time.html", html.data() as *u8, html.size())
    printf("  -> sym-binding-time.html\n")

    html = underlayer_content::render_sym_copy_reloc()
    fs::write_text_file("output/sym-copy-reloc.html", html.data() as *u8, html.size())
    printf("  -> sym-copy-reloc.html\n")

    // Module 4: Versions and Invented Symbols
    html = underlayer_content::render_sym_version()
    fs::write_text_file("output/sym-version.html", html.data() as *u8, html.size())
    printf("  -> sym-version.html\n")

    html = underlayer_content::render_sym_linker_defined()
    fs::write_text_file("output/sym-linker-defined.html", html.data() as *u8, html.size())
    printf("  -> sym-linker-defined.html\n")

    printf("Done: 12 concepts + landing page\n")
    return 0
}
