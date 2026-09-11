// ELF Course — Build entry point
// Calls render functions for each concept, writes pre-rendered HTML output.
using std::string
using std::string_view

import bytes

public func main() : int {
    printf("[elf-course] Generating course pages...\n")

    // Create output directory
    var output_dir = std::string("lang/compiled/underlayer/courses/elf/output")
    underlayer_core::mkdir(&raw output_dir)

    // Render each concept
    var bytes_html = bytes::render_bytes()
    write_output("lang/compiled/underlayer/courses/elf/output/bytes.html", &raw bytes_html)

    printf("[elf-course] Done. Generated pages in courses/elf/output/\n")
    return 0
}

private func write_output(path : *string, content : *string) {
    var f = fopen(path.data(), "wb")
    if(f == null) {
        printf("[elf-course] Error: could not create %s\n", path.data())
        return
    }
    fwrite(content.data(), 1, content.size(), f)
    fclose(f)
    printf("[elf-course] Wrote %s\n", path.data())
}
