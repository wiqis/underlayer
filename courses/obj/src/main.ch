// Object Files - Build entry point
// Renders concept pages to output/. Concepts are added as they are written.

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

    printf("Object Files: 4 of 18 concepts generated in output/\n")
    return 0
}
