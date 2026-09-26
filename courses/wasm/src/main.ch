// WebAssembly Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering WebAssembly course pages...\n")

    // Module 1: The Container
    var html = underlayer_content::render_wasm_intro()
    fs::write_text_file("output/wasm-intro.html", html.data() as *u8, html.size())
    printf("  -> wasm-intro.html\n")

    html = underlayer_content::render_wasm_header()
    fs::write_text_file("output/wasm-header.html", html.data() as *u8, html.size())
    printf("  -> wasm-header.html\n")

    html = underlayer_content::render_wasm_sections()
    fs::write_text_file("output/wasm-sections.html", html.data() as *u8, html.size())
    printf("  -> wasm-sections.html\n")

    html = underlayer_content::render_wasm_leb128()
    fs::write_text_file("output/wasm-leb128.html", html.data() as *u8, html.size())
    printf("  -> wasm-leb128.html\n")

    // Module 2: Declarations
    html = underlayer_content::render_wasm_types()
    fs::write_text_file("output/wasm-types.html", html.data() as *u8, html.size())
    printf("  -> wasm-types.html\n")

    html = underlayer_content::render_wasm_imports()
    fs::write_text_file("output/wasm-imports.html", html.data() as *u8, html.size())
    printf("  -> wasm-imports.html\n")

    html = underlayer_content::render_wasm_tables_memories()
    fs::write_text_file("output/wasm-tables-memories.html", html.data() as *u8, html.size())
    printf("  -> wasm-tables-memories.html\n")

    html = underlayer_content::render_wasm_globals()
    fs::write_text_file("output/wasm-globals.html", html.data() as *u8, html.size())
    printf("  -> wasm-globals.html\n")

    // Module 3: The Body
    html = underlayer_content::render_wasm_code()
    fs::write_text_file("output/wasm-code.html", html.data() as *u8, html.size())
    printf("  -> wasm-code.html\n")

    html = underlayer_content::render_wasm_instructions()
    fs::write_text_file("output/wasm-instructions.html", html.data() as *u8, html.size())
    printf("  -> wasm-instructions.html\n")

    // Module 4: Data Placement
    html = underlayer_content::render_wasm_elements()
    fs::write_text_file("output/wasm-elements.html", html.data() as *u8, html.size())
    printf("  -> wasm-elements.html\n")

    html = underlayer_content::render_wasm_data()
    fs::write_text_file("output/wasm-data.html", html.data() as *u8, html.size())
    printf("  -> wasm-data.html\n")

    // Module 5: Objects and Tooling
    html = underlayer_content::render_wasm_objects()
    fs::write_text_file("output/wasm-objects.html", html.data() as *u8, html.size())
    printf("  -> wasm-objects.html\n")

    // Landing page
    html = underlayer_content::render_wasm_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("WebAssembly course: 13 concepts + landing page generated in output/\n")
    return 0
}
