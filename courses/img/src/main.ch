// Executable Images and OS Loading — build entry point.
// Renders all 6 concept pages plus the landing page to output/.
//
// Concept order: the handoff first (the auxv is the mechanism and nothing
// else in the course works without it), then how to read the values in it,
// then the address layout the kernel chose, then rebuild the reader.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Executable Images pages...\n")

    var html = underlayer_content::render_img_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Handoff
    html = underlayer_content::render_img_auxv()
    fs::write_text_file("output/img-auxv.html", html.data() as *u8, html.size())
    printf("  -> img-auxv.html\n")

    html = underlayer_content::render_img_stack()
    fs::write_text_file("output/img-stack.html", html.data() as *u8, html.size())
    printf("  -> img-stack.html\n")

    // Module 2: Reading the Values
    html = underlayer_content::render_img_entries()
    fs::write_text_file("output/img-entries.html", html.data() as *u8, html.size())
    printf("  -> img-entries.html\n")

    html = underlayer_content::render_img_vdso()
    fs::write_text_file("output/img-vdso.html", html.data() as *u8, html.size())
    printf("  -> img-vdso.html\n")

    // Module 3: The Layout
    html = underlayer_content::render_img_place()
    fs::write_text_file("output/img-place.html", html.data() as *u8, html.size())
    printf("  -> img-place.html\n")

    // Module 4: Rebuild It
    html = underlayer_content::render_img_walk()
    fs::write_text_file("output/img-walk.html", html.data() as *u8, html.size())
    printf("  -> img-walk.html\n")

    printf("Done: 6 concepts + landing page\n")
    return 0
}
