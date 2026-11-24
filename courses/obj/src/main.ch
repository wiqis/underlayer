// Object Files - Build entry point
// Renders all 18 concept pages plus the landing page to output/.
//
// Concept order follows the dependency chain, not the order the files were
// written in: a concept's "Previous" footer is the concept that introduced
// what it assumes. Modules are in the manifest; this list is the order a
// learner walks.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Object Files pages...`)

    // Module 1: Why Object Files Exist
    var html = underlayer_content::render_obj_intro()
    course_writer::write_page("output/obj-intro.html", &html)
    println(`  -> obj-intro.html`)

    html = underlayer_content::render_obj_the_hole()
    course_writer::write_page("output/obj-the-hole.html", &html)
    println(`  -> obj-the-hole.html`)

    html = underlayer_content::render_obj_triangulate()
    course_writer::write_page("output/obj-triangulate.html", &html)
    println(`  -> obj-triangulate.html`)

    html = underlayer_content::render_obj_no_segments()
    course_writer::write_page("output/obj-no-segments.html", &html)
    println(`  -> obj-no-segments.html`)

    // Module 2: Anatomy, Compared
    html = underlayer_content::render_obj_sections()
    course_writer::write_page("output/obj-sections.html", &html)
    println(`  -> obj-sections.html`)

    html = underlayer_content::render_obj_symbols()
    course_writer::write_page("output/obj-symbols.html", &html)
    println(`  -> obj-symbols.html`)

    html = underlayer_content::render_obj_strings()
    course_writer::write_page("output/obj-strings.html", &html)
    println(`  -> obj-strings.html`)

    html = underlayer_content::render_obj_bss_common()
    course_writer::write_page("output/obj-bss-common.html", &html)
    println(`  -> obj-bss-common.html`)

    // Module 3: The Fixup
    html = underlayer_content::render_obj_relocations()
    course_writer::write_page("output/obj-relocations.html", &html)
    println(`  -> obj-relocations.html`)

    html = underlayer_content::render_obj_addends()
    course_writer::write_page("output/obj-addends.html", &html)
    println(`  -> obj-addends.html`)

    html = underlayer_content::render_obj_reloc_tables()
    course_writer::write_page("output/obj-reloc-tables.html", &html)
    println(`  -> obj-reloc-tables.html`)

    html = underlayer_content::render_obj_pic()
    course_writer::write_page("output/obj-pic.html", &html)
    println(`  -> obj-pic.html`)

    // Module 4: Merging and Selection
    html = underlayer_content::render_obj_comdat_group()
    course_writer::write_page("output/obj-comdat-group.html", &html)
    println(`  -> obj-comdat-group.html`)

    html = underlayer_content::render_obj_archives()
    course_writer::write_page("output/obj-archives.html", &html)
    println(`  -> obj-archives.html`)

    html = underlayer_content::render_obj_weak_undef()
    course_writer::write_page("output/obj-weak-undef.html", &html)
    println(`  -> obj-weak-undef.html`)

    // Module 5: Emitting One
    html = underlayer_content::render_obj_emit()
    course_writer::write_page("output/obj-emit.html", &html)
    println(`  -> obj-emit.html`)

    html = underlayer_content::render_obj_arch_table()
    course_writer::write_page("output/obj-arch-table.html", &html)
    println(`  -> obj-arch-table.html`)

    html = underlayer_content::render_obj_verify()
    course_writer::write_page("output/obj-verify.html", &html)
    println(`  -> obj-verify.html`)

    // Landing page
    html = underlayer_content::render_obj_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    println(`Object Files: 18 concepts + landing page generated in output/`)
    return 0
}
