// WebAssembly Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering WebAssembly course pages...`)

    // Module 1: The Container
    var html = underlayer_content::render_wasm_intro()
    course_writer::write_page("output/wasm-intro.html", &html)
    println(`  -> wasm-intro.html`)

    html = underlayer_content::render_wasm_header()
    course_writer::write_page("output/wasm-header.html", &html)
    println(`  -> wasm-header.html`)

    html = underlayer_content::render_wasm_sections()
    course_writer::write_page("output/wasm-sections.html", &html)
    println(`  -> wasm-sections.html`)

    html = underlayer_content::render_wasm_leb128()
    course_writer::write_page("output/wasm-leb128.html", &html)
    println(`  -> wasm-leb128.html`)

    // Module 2: Declarations
    html = underlayer_content::render_wasm_types()
    course_writer::write_page("output/wasm-types.html", &html)
    println(`  -> wasm-types.html`)

    html = underlayer_content::render_wasm_imports()
    course_writer::write_page("output/wasm-imports.html", &html)
    println(`  -> wasm-imports.html`)

    html = underlayer_content::render_wasm_tables_memories()
    course_writer::write_page("output/wasm-tables-memories.html", &html)
    println(`  -> wasm-tables-memories.html`)

    html = underlayer_content::render_wasm_globals()
    course_writer::write_page("output/wasm-globals.html", &html)
    println(`  -> wasm-globals.html`)

    // Module 3: The Body
    html = underlayer_content::render_wasm_code()
    course_writer::write_page("output/wasm-code.html", &html)
    println(`  -> wasm-code.html`)

    html = underlayer_content::render_wasm_instructions()
    course_writer::write_page("output/wasm-instructions.html", &html)
    println(`  -> wasm-instructions.html`)

    // Module 4: Data Placement
    html = underlayer_content::render_wasm_elements()
    course_writer::write_page("output/wasm-elements.html", &html)
    println(`  -> wasm-elements.html`)

    html = underlayer_content::render_wasm_data()
    course_writer::write_page("output/wasm-data.html", &html)
    println(`  -> wasm-data.html`)

    // Module 5: Objects and Tooling
    html = underlayer_content::render_wasm_objects()
    course_writer::write_page("output/wasm-objects.html", &html)
    println(`  -> wasm-objects.html`)

    // Landing page
    html = underlayer_content::render_wasm_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    println(`WebAssembly course: 13 concepts + landing page generated in output/`)
    return 0
}
