// PE Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering PE course pages...\n")

    // Module 1: Fundamentals
    var html = underlayer_content::render_pe_intro()
    fs::write_text_file("output/pe-intro.html", html.data() as *u8, html.size())
    printf("  -> pe-intro.html\n")

    html = underlayer_content::render_pe_file_layout()
    fs::write_text_file("output/pe-file-layout.html", html.data() as *u8, html.size())
    printf("  -> pe-file-layout.html\n")

    html = underlayer_content::render_pe_coff_basics()
    fs::write_text_file("output/pe-coff-basics.html", html.data() as *u8, html.size())
    printf("  -> pe-coff-basics.html\n")

    // Module 2: Headers
    html = underlayer_content::render_pe_dos_header()
    fs::write_text_file("output/pe-dos-header.html", html.data() as *u8, html.size())
    printf("  -> pe-dos-header.html\n")

    html = underlayer_content::render_pe_signature_coff()
    fs::write_text_file("output/pe-signature-coff.html", html.data() as *u8, html.size())
    printf("  -> pe-signature-coff.html\n")

    html = underlayer_content::render_pe_optional_header()
    fs::write_text_file("output/pe-optional-header.html", html.data() as *u8, html.size())
    printf("  -> pe-optional-header.html\n")

    // Module 3: Addressing & Data Directories
    html = underlayer_content::render_pe_data_directories()
    fs::write_text_file("output/pe-data-directories.html", html.data() as *u8, html.size())
    printf("  -> pe-data-directories.html\n")

    html = underlayer_content::render_pe_addresses()
    fs::write_text_file("output/pe-addresses.html", html.data() as *u8, html.size())
    printf("  -> pe-addresses.html\n")

    html = underlayer_content::render_pe_rva_conversion()
    fs::write_text_file("output/pe-rva-conversion.html", html.data() as *u8, html.size())
    printf("  -> pe-rva-conversion.html\n")

    // Module 4: Sections
    html = underlayer_content::render_pe_section_table()
    fs::write_text_file("output/pe-section-table.html", html.data() as *u8, html.size())
    printf("  -> pe-section-table.html\n")

    html = underlayer_content::render_pe_common_sections()
    fs::write_text_file("output/pe-common-sections.html", html.data() as *u8, html.size())
    printf("  -> pe-common-sections.html\n")

    html = underlayer_content::render_pe_alignment()
    fs::write_text_file("output/pe-alignment.html", html.data() as *u8, html.size())
    printf("  -> pe-alignment.html\n")

    // Module 5: Imports & Exports
    html = underlayer_content::render_pe_imports()
    fs::write_text_file("output/pe-imports.html", html.data() as *u8, html.size())
    printf("  -> pe-imports.html\n")

    html = underlayer_content::render_pe_exports()
    fs::write_text_file("output/pe-exports.html", html.data() as *u8, html.size())
    printf("  -> pe-exports.html\n")

    html = underlayer_content::render_pe_delay_loads()
    fs::write_text_file("output/pe-delay-loads.html", html.data() as *u8, html.size())
    printf("  -> pe-delay-loads.html\n")

    // Module 6: Relocations & Hardening
    html = underlayer_content::render_pe_base_relocations()
    fs::write_text_file("output/pe-base-relocations.html", html.data() as *u8, html.size())
    printf("  -> pe-base-relocations.html\n")

    html = underlayer_content::render_pe_security_flags()
    fs::write_text_file("output/pe-security-flags.html", html.data() as *u8, html.size())
    printf("  -> pe-security-flags.html\n")

    html = underlayer_content::render_pe_load_config()
    fs::write_text_file("output/pe-load-config.html", html.data() as *u8, html.size())
    printf("  -> pe-load-config.html\n")

    // Module 7: Resources & Runtime Tables
    html = underlayer_content::render_pe_resources()
    fs::write_text_file("output/pe-resources.html", html.data() as *u8, html.size())
    printf("  -> pe-resources.html\n")

    html = underlayer_content::render_pe_tls()
    fs::write_text_file("output/pe-tls.html", html.data() as *u8, html.size())
    printf("  -> pe-tls.html\n")

    html = underlayer_content::render_pe_exceptions()
    fs::write_text_file("output/pe-exceptions.html", html.data() as *u8, html.size())
    printf("  -> pe-exceptions.html\n")

    // Module 8: Loading & Execution
    html = underlayer_content::render_pe_loader()
    fs::write_text_file("output/pe-loader.html", html.data() as *u8, html.size())
    printf("  -> pe-loader.html\n")

    html = underlayer_content::render_pe_memory_layout()
    fs::write_text_file("output/pe-memory-layout.html", html.data() as *u8, html.size())
    printf("  -> pe-memory-layout.html\n")

    html = underlayer_content::render_pe_execution()
    fs::write_text_file("output/pe-execution.html", html.data() as *u8, html.size())
    printf("  -> pe-execution.html\n")

    // Landing page
    html = underlayer_content::render_pe_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("PE course: 24 concepts + landing page generated in output/\n")
    return 0
}
