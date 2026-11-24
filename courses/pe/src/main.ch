// PE Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering PE course pages...`)

    // Module 1: Fundamentals
    var html = underlayer_content::render_pe_intro()
    course_writer::write_page("output/pe-intro.html", &html)
    println(`  -> pe-intro.html`)

    html = underlayer_content::render_pe_file_layout()
    course_writer::write_page("output/pe-file-layout.html", &html)
    println(`  -> pe-file-layout.html`)

    html = underlayer_content::render_pe_coff_basics()
    course_writer::write_page("output/pe-coff-basics.html", &html)
    println(`  -> pe-coff-basics.html`)

    // Module 2: Headers
    html = underlayer_content::render_pe_dos_header()
    course_writer::write_page("output/pe-dos-header.html", &html)
    println(`  -> pe-dos-header.html`)

    html = underlayer_content::render_pe_signature_coff()
    course_writer::write_page("output/pe-signature-coff.html", &html)
    println(`  -> pe-signature-coff.html`)

    html = underlayer_content::render_pe_optional_header()
    course_writer::write_page("output/pe-optional-header.html", &html)
    println(`  -> pe-optional-header.html`)

    // Module 3: Addressing & Data Directories
    html = underlayer_content::render_pe_data_directories()
    course_writer::write_page("output/pe-data-directories.html", &html)
    println(`  -> pe-data-directories.html`)

    html = underlayer_content::render_pe_addresses()
    course_writer::write_page("output/pe-addresses.html", &html)
    println(`  -> pe-addresses.html`)

    html = underlayer_content::render_pe_rva_conversion()
    course_writer::write_page("output/pe-rva-conversion.html", &html)
    println(`  -> pe-rva-conversion.html`)

    // Module 4: Sections
    html = underlayer_content::render_pe_section_table()
    course_writer::write_page("output/pe-section-table.html", &html)
    println(`  -> pe-section-table.html`)

    html = underlayer_content::render_pe_common_sections()
    course_writer::write_page("output/pe-common-sections.html", &html)
    println(`  -> pe-common-sections.html`)

    html = underlayer_content::render_pe_alignment()
    course_writer::write_page("output/pe-alignment.html", &html)
    println(`  -> pe-alignment.html`)

    // Module 5: Imports & Exports
    html = underlayer_content::render_pe_imports()
    course_writer::write_page("output/pe-imports.html", &html)
    println(`  -> pe-imports.html`)

    html = underlayer_content::render_pe_exports()
    course_writer::write_page("output/pe-exports.html", &html)
    println(`  -> pe-exports.html`)

    html = underlayer_content::render_pe_delay_loads()
    course_writer::write_page("output/pe-delay-loads.html", &html)
    println(`  -> pe-delay-loads.html`)

    // Module 6: Relocations & Hardening
    html = underlayer_content::render_pe_base_relocations()
    course_writer::write_page("output/pe-base-relocations.html", &html)
    println(`  -> pe-base-relocations.html`)

    html = underlayer_content::render_pe_security_flags()
    course_writer::write_page("output/pe-security-flags.html", &html)
    println(`  -> pe-security-flags.html`)

    html = underlayer_content::render_pe_load_config()
    course_writer::write_page("output/pe-load-config.html", &html)
    println(`  -> pe-load-config.html`)

    // Module 7: Resources & Runtime Tables
    html = underlayer_content::render_pe_resources()
    course_writer::write_page("output/pe-resources.html", &html)
    println(`  -> pe-resources.html`)

    html = underlayer_content::render_pe_tls()
    course_writer::write_page("output/pe-tls.html", &html)
    println(`  -> pe-tls.html`)

    html = underlayer_content::render_pe_exceptions()
    course_writer::write_page("output/pe-exceptions.html", &html)
    println(`  -> pe-exceptions.html`)

    // Module 8: Loading & Execution
    html = underlayer_content::render_pe_loader()
    course_writer::write_page("output/pe-loader.html", &html)
    println(`  -> pe-loader.html`)

    html = underlayer_content::render_pe_memory_layout()
    course_writer::write_page("output/pe-memory-layout.html", &html)
    println(`  -> pe-memory-layout.html`)

    html = underlayer_content::render_pe_execution()
    course_writer::write_page("output/pe-execution.html", &html)
    println(`  -> pe-execution.html`)

    // Landing page
    html = underlayer_content::render_pe_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    println(`PE course: 24 concepts + landing page generated in output/`)
    return 0
}
