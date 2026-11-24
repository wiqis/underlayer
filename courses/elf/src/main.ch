// ELF Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering ELF course pages...`)

    // Module 1: Fundamentals
    var html = underlayer_content::render_bytes()
    course_writer::write_page("output/bytes.html", &html)
    println(`  -> bytes.html`)

    html = underlayer_content::render_binary_representation()
    course_writer::write_page("output/binary-representation.html", &html)
    println(`  -> binary-representation.html`)

    html = underlayer_content::render_file_layout()
    course_writer::write_page("output/file-layout.html", &html)
    println(`  -> file-layout.html`)

    // Module 2: ELF Header
    html = underlayer_content::render_elf_identification()
    course_writer::write_page("output/elf-identification.html", &html)
    println(`  -> elf-identification.html`)

    html = underlayer_content::render_elf_header_fields()
    course_writer::write_page("output/elf-header-fields.html", &html)
    println(`  -> elf-header-fields.html`)

    html = underlayer_content::render_entry_point()
    course_writer::write_page("output/entry-point.html", &html)
    println(`  -> entry-point.html`)

    // Module 3: Program Headers
    html = underlayer_content::render_program_header_table()
    course_writer::write_page("output/program-header-table.html", &html)
    println(`  -> program-header-table.html`)

    html = underlayer_content::render_segment_types()
    course_writer::write_page("output/segment-types.html", &html)
    println(`  -> segment-types.html`)

    html = underlayer_content::render_memory_mapping()
    course_writer::write_page("output/memory-mapping.html", &html)
    println(`  -> memory-mapping.html`)

    // Module 4: Sections
    html = underlayer_content::render_section_header_table()
    course_writer::write_page("output/section-header-table.html", &html)
    println(`  -> section-header-table.html`)

    html = underlayer_content::render_common_sections()
    course_writer::write_page("output/common-sections.html", &html)
    println(`  -> common-sections.html`)

    html = underlayer_content::render_section_vs_segment()
    course_writer::write_page("output/section-vs-segment.html", &html)
    println(`  -> section-vs-segment.html`)

    // Module 5: Symbols
    html = underlayer_content::render_symbol_table()
    course_writer::write_page("output/symbol-table.html", &html)
    println(`  -> symbol-table.html`)

    html = underlayer_content::render_binding()
    course_writer::write_page("output/binding.html", &html)
    println(`  -> binding.html`)

    html = underlayer_content::render_visibility()
    course_writer::write_page("output/visibility.html", &html)
    println(`  -> visibility.html`)

    // Module 6: Relocations
    html = underlayer_content::render_relocation_entries()
    course_writer::write_page("output/relocation-entries.html", &html)
    println(`  -> relocation-entries.html`)

    html = underlayer_content::render_relocation_types()
    course_writer::write_page("output/relocation-types.html", &html)
    println(`  -> relocation-types.html`)

    html = underlayer_content::render_dynamic_relocations()
    course_writer::write_page("output/dynamic-relocations.html", &html)
    println(`  -> dynamic-relocations.html`)

    // Module 7: Dynamic Linking
    html = underlayer_content::render_dynamic_section()
    course_writer::write_page("output/dynamic-section.html", &html)
    println(`  -> dynamic-section.html`)

    html = underlayer_content::render_shared_libraries()
    course_writer::write_page("output/shared-libraries.html", &html)
    println(`  -> shared-libraries.html`)

    html = underlayer_content::render_ld_so()
    course_writer::write_page("output/ld-so.html", &html)
    println(`  -> ld-so.html`)

    // Module 8: Loading & Execution
    html = underlayer_content::render_loader()
    course_writer::write_page("output/loader.html", &html)
    println(`  -> loader.html`)

    html = underlayer_content::render_memory_layout()
    course_writer::write_page("output/memory-layout.html", &html)
    println(`  -> memory-layout.html`)

    html = underlayer_content::render_execution()
    course_writer::write_page("output/execution.html", &html)
    println(`  -> execution.html`)

    // Landing page
    html = underlayer_content::render_elf_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    println(`ELF course: 24 concepts + landing page generated in output/`)
    return 0
}
