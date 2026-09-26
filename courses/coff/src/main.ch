// COFF Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering COFF course pages...\n")

    // Module 1: The Relocatable Object
    var html = underlayer_content::render_coff_intro()
    fs::write_text_file("output/coff-intro.html", html.data() as *u8, html.size())
    printf("  -> coff-intro.html\n")

    html = underlayer_content::render_coff_file_header()
    fs::write_text_file("output/coff-file-header.html", html.data() as *u8, html.size())
    printf("  -> coff-file-header.html\n")

    html = underlayer_content::render_coff_section_table()
    fs::write_text_file("output/coff-section-table.html", html.data() as *u8, html.size())
    printf("  -> coff-section-table.html\n")

    html = underlayer_content::render_coff_characteristics()
    fs::write_text_file("output/coff-characteristics.html", html.data() as *u8, html.size())
    printf("  -> coff-characteristics.html\n")

    // Module 2: Symbols and Relocations
    html = underlayer_content::render_coff_string_table()
    fs::write_text_file("output/coff-string-table.html", html.data() as *u8, html.size())
    printf("  -> coff-string-table.html\n")

    html = underlayer_content::render_coff_symbol_table()
    fs::write_text_file("output/coff-symbol-table.html", html.data() as *u8, html.size())
    printf("  -> coff-symbol-table.html\n")

    html = underlayer_content::render_coff_relocations()
    fs::write_text_file("output/coff-relocations.html", html.data() as *u8, html.size())
    printf("  -> coff-relocations.html\n")

    html = underlayer_content::render_coff_comdat()
    fs::write_text_file("output/coff-comdat.html", html.data() as *u8, html.size())
    printf("  -> coff-comdat.html\n")

    // Module 3: Containers and Variants
    html = underlayer_content::render_coff_bigobj()
    fs::write_text_file("output/coff-bigobj.html", html.data() as *u8, html.size())
    printf("  -> coff-bigobj.html\n")

    html = underlayer_content::render_coff_archives()
    fs::write_text_file("output/coff-archives.html", html.data() as *u8, html.size())
    printf("  -> coff-archives.html\n")

    html = underlayer_content::render_coff_line_numbers()
    fs::write_text_file("output/coff-line-numbers.html", html.data() as *u8, html.size())
    printf("  -> coff-line-numbers.html\n")


    // Module 4: The Link
    html = underlayer_content::render_coff_linking()
    fs::write_text_file("output/coff-linking.html", html.data() as *u8, html.size())
    printf("  -> coff-linking.html\n")

    html = underlayer_content::render_coff_map_files()
    fs::write_text_file("output/coff-map-files.html", html.data() as *u8, html.size())
    printf("  -> coff-map-files.html\n")

    html = underlayer_content::render_coff_comdat_linking()
    fs::write_text_file("output/coff-comdat-linking.html", html.data() as *u8, html.size())
    printf("  -> coff-comdat-linking.html\n")


    // Module 5: Other Targets and Other Sections
    html = underlayer_content::render_coff_arm64()
    fs::write_text_file("output/coff-arm64.html", html.data() as *u8, html.size())
    printf("  -> coff-arm64.html\n")

    html = underlayer_content::render_coff_tls()
    fs::write_text_file("output/coff-tls.html", html.data() as *u8, html.size())
    printf("  -> coff-tls.html\n")

    html = underlayer_content::render_coff_weak_externals()
    fs::write_text_file("output/coff-weak-externals.html", html.data() as *u8, html.size())
    printf("  -> coff-weak-externals.html\n")

    html = underlayer_content::render_coff_drectve()
    fs::write_text_file("output/coff-drectve.html", html.data() as *u8, html.size())
    printf("  -> coff-drectve.html\n")

    // Landing page
    html = underlayer_content::render_coff_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("COFF course: 18 concepts + landing page generated in output/\n")
    return 0
}
