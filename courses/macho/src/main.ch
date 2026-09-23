// Mach-O Course - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Mach-O course pages...\n")

    // Module 1: Fundamentals
    var html = underlayer_content::render_macho_intro()
    fs::write_text_file("output/macho-intro.html", html.data() as *u8, html.size())
    printf("  -> macho-intro.html\n")

    html = underlayer_content::render_macho_file_layout()
    fs::write_text_file("output/macho-file-layout.html", html.data() as *u8, html.size())
    printf("  -> macho-file-layout.html\n")

    html = underlayer_content::render_macho_magic()
    fs::write_text_file("output/macho-magic.html", html.data() as *u8, html.size())
    printf("  -> macho-magic.html\n")

    // Module 2: Headers
    html = underlayer_content::render_macho_header()
    fs::write_text_file("output/macho-header.html", html.data() as *u8, html.size())
    printf("  -> macho-header.html\n")

    html = underlayer_content::render_macho_cputypes()
    fs::write_text_file("output/macho-cputypes.html", html.data() as *u8, html.size())
    printf("  -> macho-cputypes.html\n")

    html = underlayer_content::render_macho_universal()
    fs::write_text_file("output/macho-universal.html", html.data() as *u8, html.size())
    printf("  -> macho-universal.html\n")

    // Module 3: Load Commands
    html = underlayer_content::render_macho_load_commands()
    fs::write_text_file("output/macho-load-commands.html", html.data() as *u8, html.size())
    printf("  -> macho-load-commands.html\n")

    html = underlayer_content::render_macho_segments()
    fs::write_text_file("output/macho-segments.html", html.data() as *u8, html.size())
    printf("  -> macho-segments.html\n")

    html = underlayer_content::render_macho_sections()
    fs::write_text_file("output/macho-sections.html", html.data() as *u8, html.size())
    printf("  -> macho-sections.html\n")

    // Module 4: Symbols
    html = underlayer_content::render_macho_symtab()
    fs::write_text_file("output/macho-symtab.html", html.data() as *u8, html.size())
    printf("  -> macho-symtab.html\n")

    html = underlayer_content::render_macho_dysymtab()
    fs::write_text_file("output/macho-dysymtab.html", html.data() as *u8, html.size())
    printf("  -> macho-dysymtab.html\n")

    html = underlayer_content::render_macho_relocations()
    fs::write_text_file("output/macho-relocations.html", html.data() as *u8, html.size())
    printf("  -> macho-relocations.html\n")

    // Module 5: Dynamic Linking
    html = underlayer_content::render_macho_dylibs()
    fs::write_text_file("output/macho-dylibs.html", html.data() as *u8, html.size())
    printf("  -> macho-dylibs.html\n")

    html = underlayer_content::render_macho_dyld_info()
    fs::write_text_file("output/macho-dyld-info.html", html.data() as *u8, html.size())
    printf("  -> macho-dyld-info.html\n")

    html = underlayer_content::render_macho_export_trie()
    fs::write_text_file("output/macho-export-trie.html", html.data() as *u8, html.size())
    printf("  -> macho-export-trie.html\n")

    // Module 6: Modern Linking & Entry
    html = underlayer_content::render_macho_chained_fixups()
    fs::write_text_file("output/macho-chained-fixups.html", html.data() as *u8, html.size())
    printf("  -> macho-chained-fixups.html\n")

    html = underlayer_content::render_macho_entry()
    fs::write_text_file("output/macho-entry.html", html.data() as *u8, html.size())
    printf("  -> macho-entry.html\n")

    html = underlayer_content::render_macho_build_version()
    fs::write_text_file("output/macho-build-version.html", html.data() as *u8, html.size())
    printf("  -> macho-build-version.html\n")

    // Module 7: Integrity & Debug
    html = underlayer_content::render_macho_code_signing()
    fs::write_text_file("output/macho-code-signing.html", html.data() as *u8, html.size())
    printf("  -> macho-code-signing.html\n")

    html = underlayer_content::render_macho_debug_info()
    fs::write_text_file("output/macho-debug-info.html", html.data() as *u8, html.size())
    printf("  -> macho-debug-info.html\n")

    html = underlayer_content::render_macho_hardening()
    fs::write_text_file("output/macho-hardening.html", html.data() as *u8, html.size())
    printf("  -> macho-hardening.html\n")

    // Module 8: Loading & Execution
    html = underlayer_content::render_macho_dyld()
    fs::write_text_file("output/macho-dyld.html", html.data() as *u8, html.size())
    printf("  -> macho-dyld.html\n")

    html = underlayer_content::render_macho_memory_layout()
    fs::write_text_file("output/macho-memory-layout.html", html.data() as *u8, html.size())
    printf("  -> macho-memory-layout.html\n")

    html = underlayer_content::render_macho_execution()
    fs::write_text_file("output/macho-execution.html", html.data() as *u8, html.size())
    printf("  -> macho-execution.html\n")

    // Landing page
    html = underlayer_content::render_macho_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("Mach-O course: 24 concepts + landing page generated in output/\n")
    return 0
}
