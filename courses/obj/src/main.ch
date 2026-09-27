// Object Files - Build entry point
// Renders all 18 concept pages plus the landing page to output/.
//
// Concept order follows the dependency chain, not the order the files were
// written in: a concept's "Previous" footer is the concept that introduced
// what it assumes. Modules are in the manifest; this list is the order a
// learner walks.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Object Files pages...\n")

    // Module 1: Why Object Files Exist
    var html = underlayer_content::render_obj_intro()
    fs::write_text_file("output/obj-intro.html", html.data() as *u8, html.size())
    printf("  -> obj-intro.html\n")

    html = underlayer_content::render_obj_the_hole()
    fs::write_text_file("output/obj-the-hole.html", html.data() as *u8, html.size())
    printf("  -> obj-the-hole.html\n")

    html = underlayer_content::render_obj_triangulate()
    fs::write_text_file("output/obj-triangulate.html", html.data() as *u8, html.size())
    printf("  -> obj-triangulate.html\n")

    html = underlayer_content::render_obj_no_segments()
    fs::write_text_file("output/obj-no-segments.html", html.data() as *u8, html.size())
    printf("  -> obj-no-segments.html\n")

    // Module 2: Anatomy, Compared
    html = underlayer_content::render_obj_sections()
    fs::write_text_file("output/obj-sections.html", html.data() as *u8, html.size())
    printf("  -> obj-sections.html\n")

    html = underlayer_content::render_obj_symbols()
    fs::write_text_file("output/obj-symbols.html", html.data() as *u8, html.size())
    printf("  -> obj-symbols.html\n")

    html = underlayer_content::render_obj_strings()
    fs::write_text_file("output/obj-strings.html", html.data() as *u8, html.size())
    printf("  -> obj-strings.html\n")

    html = underlayer_content::render_obj_bss_common()
    fs::write_text_file("output/obj-bss-common.html", html.data() as *u8, html.size())
    printf("  -> obj-bss-common.html\n")

    // Module 3: The Fixup
    html = underlayer_content::render_obj_relocations()
    fs::write_text_file("output/obj-relocations.html", html.data() as *u8, html.size())
    printf("  -> obj-relocations.html\n")

    html = underlayer_content::render_obj_addends()
    fs::write_text_file("output/obj-addends.html", html.data() as *u8, html.size())
    printf("  -> obj-addends.html\n")

    html = underlayer_content::render_obj_reloc_tables()
    fs::write_text_file("output/obj-reloc-tables.html", html.data() as *u8, html.size())
    printf("  -> obj-reloc-tables.html\n")

    html = underlayer_content::render_obj_pic()
    fs::write_text_file("output/obj-pic.html", html.data() as *u8, html.size())
    printf("  -> obj-pic.html\n")

    // Module 4: Merging and Selection
    html = underlayer_content::render_obj_comdat_group()
    fs::write_text_file("output/obj-comdat-group.html", html.data() as *u8, html.size())
    printf("  -> obj-comdat-group.html\n")

    html = underlayer_content::render_obj_archives()
    fs::write_text_file("output/obj-archives.html", html.data() as *u8, html.size())
    printf("  -> obj-archives.html\n")

    html = underlayer_content::render_obj_weak_undef()
    fs::write_text_file("output/obj-weak-undef.html", html.data() as *u8, html.size())
    printf("  -> obj-weak-undef.html\n")

    // Module 5: Emitting One
    html = underlayer_content::render_obj_emit()
    fs::write_text_file("output/obj-emit.html", html.data() as *u8, html.size())
    printf("  -> obj-emit.html\n")

    html = underlayer_content::render_obj_arch_table()
    fs::write_text_file("output/obj-arch-table.html", html.data() as *u8, html.size())
    printf("  -> obj-arch-table.html\n")

    html = underlayer_content::render_obj_verify()
    fs::write_text_file("output/obj-verify.html", html.data() as *u8, html.size())
    printf("  -> obj-verify.html\n")

    // Landing page
    html = underlayer_content::render_obj_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("Object Files: 18 concepts + landing page generated in output/\n")
    return 0
}
