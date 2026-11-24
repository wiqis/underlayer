// COFF Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering COFF course pages...`)

    // Module 1: The Relocatable Object
    var html = underlayer_content::render_coff_intro()
    course_writer::write_page("output/coff-intro.html", &html)
    println(`  -> coff-intro.html`)

    html = underlayer_content::render_coff_file_header()
    course_writer::write_page("output/coff-file-header.html", &html)
    println(`  -> coff-file-header.html`)

    html = underlayer_content::render_coff_section_table()
    course_writer::write_page("output/coff-section-table.html", &html)
    println(`  -> coff-section-table.html`)

    html = underlayer_content::render_coff_characteristics()
    course_writer::write_page("output/coff-characteristics.html", &html)
    println(`  -> coff-characteristics.html`)

    // Module 2: Symbols and Relocations
    html = underlayer_content::render_coff_string_table()
    course_writer::write_page("output/coff-string-table.html", &html)
    println(`  -> coff-string-table.html`)

    html = underlayer_content::render_coff_symbol_table()
    course_writer::write_page("output/coff-symbol-table.html", &html)
    println(`  -> coff-symbol-table.html`)

    html = underlayer_content::render_coff_relocations()
    course_writer::write_page("output/coff-relocations.html", &html)
    println(`  -> coff-relocations.html`)

    html = underlayer_content::render_coff_comdat()
    course_writer::write_page("output/coff-comdat.html", &html)
    println(`  -> coff-comdat.html`)

    // Module 3: Containers and Variants
    html = underlayer_content::render_coff_bigobj()
    course_writer::write_page("output/coff-bigobj.html", &html)
    println(`  -> coff-bigobj.html`)

    html = underlayer_content::render_coff_archives()
    course_writer::write_page("output/coff-archives.html", &html)
    println(`  -> coff-archives.html`)

    html = underlayer_content::render_coff_line_numbers()
    course_writer::write_page("output/coff-line-numbers.html", &html)
    println(`  -> coff-line-numbers.html`)


    // Module 4: The Link
    html = underlayer_content::render_coff_linking()
    course_writer::write_page("output/coff-linking.html", &html)
    println(`  -> coff-linking.html`)

    html = underlayer_content::render_coff_map_files()
    course_writer::write_page("output/coff-map-files.html", &html)
    println(`  -> coff-map-files.html`)

    html = underlayer_content::render_coff_comdat_linking()
    course_writer::write_page("output/coff-comdat-linking.html", &html)
    println(`  -> coff-comdat-linking.html`)


    // Module 5: Other Targets and Other Sections
    html = underlayer_content::render_coff_arm64()
    course_writer::write_page("output/coff-arm64.html", &html)
    println(`  -> coff-arm64.html`)

    html = underlayer_content::render_coff_tls()
    course_writer::write_page("output/coff-tls.html", &html)
    println(`  -> coff-tls.html`)

    html = underlayer_content::render_coff_weak_externals()
    course_writer::write_page("output/coff-weak-externals.html", &html)
    println(`  -> coff-weak-externals.html`)

    html = underlayer_content::render_coff_drectve()
    course_writer::write_page("output/coff-drectve.html", &html)
    println(`  -> coff-drectve.html`)

    // Landing page
    html = underlayer_content::render_coff_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    println(`COFF course: 18 concepts + landing page generated in output/`)
    return 0
}
