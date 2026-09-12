// ELF Course — Build entry point
// Renders all concept pages to output/ directory.
import std
import fs
import underlayer_content::bytes
import underlayer_content::binary_representation
import underlayer_content::file_layout
import underlayer_content::elf_identification
import underlayer_content::elf_header_fields
import underlayer_content::entry_point
import underlayer_content::program_header_table
import underlayer_content::segment_types
import underlayer_content::memory_mapping
import underlayer_content::section_header_table
import underlayer_content::common_sections
import underlayer_content::section_vs_segment
import underlayer_content::elf_landing

public func main() : int {
    fs::mkdir("output")
    printf("Rendering ELF course pages...\n")

    // Module 1: Fundamentals
    var html = underlayer_content::bytes::render_bytes()
    fs::write_text_file("output/bytes.html", html.data() as *u8, html.size())
    printf("  -> bytes.html\n")

    html = underlayer_content::binary_representation::render_binary_representation()
    fs::write_text_file("output/binary-representation.html", html.data() as *u8, html.size())
    printf("  -> binary-representation.html\n")

    html = underlayer_content::file_layout::render_file_layout()
    fs::write_text_file("output/file-layout.html", html.data() as *u8, html.size())
    printf("  -> file-layout.html\n")

    // Module 2: ELF Header
    html = underlayer_content::elf_identification::render_elf_identification()
    fs::write_text_file("output/elf-identification.html", html.data() as *u8, html.size())
    printf("  -> elf-identification.html\n")

    html = underlayer_content::elf_header_fields::render_elf_header_fields()
    fs::write_text_file("output/elf-header-fields.html", html.data() as *u8, html.size())
    printf("  -> elf-header-fields.html\n")

    html = underlayer_content::entry_point::render_entry_point()
    fs::write_text_file("output/entry-point.html", html.data() as *u8, html.size())
    printf("  -> entry-point.html\n")

    // Module 3: Program Headers
    html = underlayer_content::program_header_table::render_program_header_table()
    fs::write_text_file("output/program-header-table.html", html.data() as *u8, html.size())
    printf("  -> program-header-table.html\n")

    html = underlayer_content::segment_types::render_segment_types()
    fs::write_text_file("output/segment-types.html", html.data() as *u8, html.size())
    printf("  -> segment-types.html\n")

    html = underlayer_content::memory_mapping::render_memory_mapping()
    fs::write_text_file("output/memory-mapping.html", html.data() as *u8, html.size())
    printf("  -> memory-mapping.html\n")

    // Module 4: Sections
    html = underlayer_content::section_header_table::render_section_header_table()
    fs::write_text_file("output/section-header-table.html", html.data() as *u8, html.size())
    printf("  -> section-header-table.html\n")

    html = underlayer_content::common_sections::render_common_sections()
    fs::write_text_file("output/common-sections.html", html.data() as *u8, html.size())
    printf("  -> common-sections.html\n")

    html = underlayer_content::section_vs_segment::render_section_vs_segment()
    fs::write_text_file("output/section-vs-segment.html", html.data() as *u8, html.size())
    printf("  -> section-vs-segment.html\n")

    // Landing page
    html = underlayer_content::elf_landing::render_elf_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("ELF course: 12 concepts + landing page generated in output/\n")
    return 0
}
