// Mach-O Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Mach-O course pages...`)

    // Module 1: Fundamentals
    var html = underlayer_content::render_macho_intro()
    course_writer::write_page("output/macho-intro.html", &html)
    println(`  -> macho-intro.html`)

    html = underlayer_content::render_macho_file_layout()
    course_writer::write_page("output/macho-file-layout.html", &html)
    println(`  -> macho-file-layout.html`)

    html = underlayer_content::render_macho_magic()
    course_writer::write_page("output/macho-magic.html", &html)
    println(`  -> macho-magic.html`)

    // Module 2: Headers
    html = underlayer_content::render_macho_header()
    course_writer::write_page("output/macho-header.html", &html)
    println(`  -> macho-header.html`)

    html = underlayer_content::render_macho_cputypes()
    course_writer::write_page("output/macho-cputypes.html", &html)
    println(`  -> macho-cputypes.html`)

    html = underlayer_content::render_macho_universal()
    course_writer::write_page("output/macho-universal.html", &html)
    println(`  -> macho-universal.html`)

    // Module 3: Load Commands
    html = underlayer_content::render_macho_load_commands()
    course_writer::write_page("output/macho-load-commands.html", &html)
    println(`  -> macho-load-commands.html`)

    html = underlayer_content::render_macho_segments()
    course_writer::write_page("output/macho-segments.html", &html)
    println(`  -> macho-segments.html`)

    html = underlayer_content::render_macho_sections()
    course_writer::write_page("output/macho-sections.html", &html)
    println(`  -> macho-sections.html`)

    // Module 4: Symbols
    html = underlayer_content::render_macho_symtab()
    course_writer::write_page("output/macho-symtab.html", &html)
    println(`  -> macho-symtab.html`)

    html = underlayer_content::render_macho_dysymtab()
    course_writer::write_page("output/macho-dysymtab.html", &html)
    println(`  -> macho-dysymtab.html`)

    html = underlayer_content::render_macho_relocations()
    course_writer::write_page("output/macho-relocations.html", &html)
    println(`  -> macho-relocations.html`)

    // Module 5: Dynamic Linking
    html = underlayer_content::render_macho_dylibs()
    course_writer::write_page("output/macho-dylibs.html", &html)
    println(`  -> macho-dylibs.html`)

    html = underlayer_content::render_macho_dyld_info()
    course_writer::write_page("output/macho-dyld-info.html", &html)
    println(`  -> macho-dyld-info.html`)

    html = underlayer_content::render_macho_export_trie()
    course_writer::write_page("output/macho-export-trie.html", &html)
    println(`  -> macho-export-trie.html`)

    // Module 6: Modern Linking & Entry
    html = underlayer_content::render_macho_chained_fixups()
    course_writer::write_page("output/macho-chained-fixups.html", &html)
    println(`  -> macho-chained-fixups.html`)

    html = underlayer_content::render_macho_entry()
    course_writer::write_page("output/macho-entry.html", &html)
    println(`  -> macho-entry.html`)

    html = underlayer_content::render_macho_build_version()
    course_writer::write_page("output/macho-build-version.html", &html)
    println(`  -> macho-build-version.html`)

    // Module 7: Integrity & Debug
    html = underlayer_content::render_macho_code_signing()
    course_writer::write_page("output/macho-code-signing.html", &html)
    println(`  -> macho-code-signing.html`)

    html = underlayer_content::render_macho_debug_info()
    course_writer::write_page("output/macho-debug-info.html", &html)
    println(`  -> macho-debug-info.html`)

    html = underlayer_content::render_macho_hardening()
    course_writer::write_page("output/macho-hardening.html", &html)
    println(`  -> macho-hardening.html`)

    // Module 8: Loading & Execution
    html = underlayer_content::render_macho_dyld()
    course_writer::write_page("output/macho-dyld.html", &html)
    println(`  -> macho-dyld.html`)

    html = underlayer_content::render_macho_memory_layout()
    course_writer::write_page("output/macho-memory-layout.html", &html)
    println(`  -> macho-memory-layout.html`)

    html = underlayer_content::render_macho_execution()
    course_writer::write_page("output/macho-execution.html", &html)
    println(`  -> macho-execution.html`)

    // Landing page
    html = underlayer_content::render_macho_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    println(`Mach-O course: 24 concepts + landing page generated in output/`)
    return 0
}
