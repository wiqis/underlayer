// ELF Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering ELF course pages...\n")

    // Module 1: Fundamentals
    var html = underlayer_content::render_bytes()
    fs::write_text_file("output/bytes.html", html.data() as *u8, html.size())
    printf("  -> bytes.html\n")

    html = underlayer_content::render_binary_representation()
    fs::write_text_file("output/binary-representation.html", html.data() as *u8, html.size())
    printf("  -> binary-representation.html\n")

    html = underlayer_content::render_file_layout()
    fs::write_text_file("output/file-layout.html", html.data() as *u8, html.size())
    printf("  -> file-layout.html\n")

    // Module 2: ELF Header
    html = underlayer_content::render_elf_identification()
    fs::write_text_file("output/elf-identification.html", html.data() as *u8, html.size())
    printf("  -> elf-identification.html\n")

    html = underlayer_content::render_elf_header_fields()
    fs::write_text_file("output/elf-header-fields.html", html.data() as *u8, html.size())
    printf("  -> elf-header-fields.html\n")

    html = underlayer_content::render_entry_point()
    fs::write_text_file("output/entry-point.html", html.data() as *u8, html.size())
    printf("  -> entry-point.html\n")

    // Module 3: Program Headers
    html = underlayer_content::render_program_header_table()
    fs::write_text_file("output/program-header-table.html", html.data() as *u8, html.size())
    printf("  -> program-header-table.html\n")

    html = underlayer_content::render_segment_types()
    fs::write_text_file("output/segment-types.html", html.data() as *u8, html.size())
    printf("  -> segment-types.html\n")

    html = underlayer_content::render_memory_mapping()
    fs::write_text_file("output/memory-mapping.html", html.data() as *u8, html.size())
    printf("  -> memory-mapping.html\n")

    // Module 4: Sections
    html = underlayer_content::render_section_header_table()
    fs::write_text_file("output/section-header-table.html", html.data() as *u8, html.size())
    printf("  -> section-header-table.html\n")

    html = underlayer_content::render_common_sections()
    fs::write_text_file("output/common-sections.html", html.data() as *u8, html.size())
    printf("  -> common-sections.html\n")

    html = underlayer_content::render_section_vs_segment()
    fs::write_text_file("output/section-vs-segment.html", html.data() as *u8, html.size())
    printf("  -> section-vs-segment.html\n")

    // Module 5: Symbols
    html = underlayer_content::render_symbol_table()
    fs::write_text_file("output/symbol-table.html", html.data() as *u8, html.size())
    printf("  -> symbol-table.html\n")

    html = underlayer_content::render_binding()
    fs::write_text_file("output/binding.html", html.data() as *u8, html.size())
    printf("  -> binding.html\n")

    html = underlayer_content::render_visibility()
    fs::write_text_file("output/visibility.html", html.data() as *u8, html.size())
    printf("  -> visibility.html\n")

    // Module 6: Relocations
    html = underlayer_content::render_relocation_entries()
    fs::write_text_file("output/relocation-entries.html", html.data() as *u8, html.size())
    printf("  -> relocation-entries.html\n")

    html = underlayer_content::render_relocation_types()
    fs::write_text_file("output/relocation-types.html", html.data() as *u8, html.size())
    printf("  -> relocation-types.html\n")

    html = underlayer_content::render_dynamic_relocations()
    fs::write_text_file("output/dynamic-relocations.html", html.data() as *u8, html.size())
    printf("  -> dynamic-relocations.html\n")

    // Module 7: Dynamic Linking
    html = underlayer_content::render_dynamic_section()
    fs::write_text_file("output/dynamic-section.html", html.data() as *u8, html.size())
    printf("  -> dynamic-section.html\n")

    html = underlayer_content::render_shared_libraries()
    fs::write_text_file("output/shared-libraries.html", html.data() as *u8, html.size())
    printf("  -> shared-libraries.html\n")

    html = underlayer_content::render_ld_so()
    fs::write_text_file("output/ld-so.html", html.data() as *u8, html.size())
    printf("  -> ld-so.html\n")

    // Module 8: Loading & Execution
    html = underlayer_content::render_loader()
    fs::write_text_file("output/loader.html", html.data() as *u8, html.size())
    printf("  -> loader.html\n")

    html = underlayer_content::render_memory_layout()
    fs::write_text_file("output/memory-layout.html", html.data() as *u8, html.size())
    printf("  -> memory-layout.html\n")

    html = underlayer_content::render_execution()
    fs::write_text_file("output/execution.html", html.data() as *u8, html.size())
    printf("  -> execution.html\n")

    // Landing page
    html = underlayer_content::render_elf_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("ELF course: 24 concepts + landing page generated in output/\n")
    return 0
}
