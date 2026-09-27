// Static Linking and Linker Scripts — build entry point.
// Renders all 10 concept pages plus the landing page to output/.
//
// Concept order is the dependency chain: first read the script you are already
// using, then learn to place things with it, then what it keeps and drops, and
// finally build one.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Static Linking pages...\n")

    var html = underlayer_content::render_link_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Script You Already Use
    html = underlayer_content::render_link_default_script()
    fs::write_text_file("output/link-default-script.html", html.data() as *u8, html.size())
    printf("  -> link-default-script.html\n")

    html = underlayer_content::render_link_script_language()
    fs::write_text_file("output/link-script-language.html", html.data() as *u8, html.size())
    printf("  -> link-script-language.html\n")

    html = underlayer_content::render_link_order()
    fs::write_text_file("output/link-order.html", html.data() as *u8, html.size())
    printf("  -> link-order.html\n")

    // Module 2: Placing Things
    html = underlayer_content::render_link_location_counter()
    fs::write_text_file("output/link-location-counter.html", html.data() as *u8, html.size())
    printf("  -> link-location-counter.html\n")

    html = underlayer_content::render_link_memory_regions()
    fs::write_text_file("output/link-memory-regions.html", html.data() as *u8, html.size())
    printf("  -> link-memory-regions.html\n")

    html = underlayer_content::render_link_phdrs()
    fs::write_text_file("output/link-phdrs.html", html.data() as *u8, html.size())
    printf("  -> link-phdrs.html\n")

    // Module 3: Roots and Selection
    html = underlayer_content::render_link_keep_gc()
    fs::write_text_file("output/link-keep-gc.html", html.data() as *u8, html.size())
    printf("  -> link-keep-gc.html\n")

    html = underlayer_content::render_link_orphans()
    fs::write_text_file("output/link-orphans.html", html.data() as *u8, html.size())
    printf("  -> link-orphans.html\n")

    // Module 4: Static, and Build One
    html = underlayer_content::render_link_static_real()
    fs::write_text_file("output/link-static-real.html", html.data() as *u8, html.size())
    printf("  -> link-static-real.html\n")

    html = underlayer_content::render_link_write_script()
    fs::write_text_file("output/link-write-script.html", html.data() as *u8, html.size())
    printf("  -> link-write-script.html\n")

    printf("Done: 10 concepts + landing page\n")
    return 0
}
