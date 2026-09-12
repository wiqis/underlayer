// ELF Course — Build entry point
// Calls render functions from content module and writes output files.
import std
import fs
import underlayer_content::bytes
import underlayer_content::binary_representation
import underlayer_content::elf_landing

public func main() : int {
    // Create output directory
    fs::mkdir("output")

    // Render each concept page
    printf("Rendering ELF course pages...\n")

    // Landing page
    var landing_html = underlayer_content::elf_landing::render_elf_landing()
    fs::write_text_file("output/index.html", landing_html.data() as *u8, landing_html.size())
    printf("  -> output/index.html\n")

    // Bytes concept
    var bytes_html = underlayer_content::bytes::render_bytes()
    fs::write_text_file("output/bytes.html", bytes_html.data() as *u8, bytes_html.size())
    printf("  -> output/bytes.html\n")

    // Binary Representation concept
    var binary_html = underlayer_content::binary_representation::render_binary_representation()
    fs::write_text_file("output/binary-representation.html", binary_html.data() as *u8, binary_html.size())
    printf("  -> output/binary-representation.html\n")

    printf("ELF course pages generated in output/\n")
    return 0
}
