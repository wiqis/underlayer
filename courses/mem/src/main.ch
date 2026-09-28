// The Memory Hierarchy — build entry point.
// Renders all 8 concept pages plus the landing page to output/.
//
// Concept order: the instrument first, because every number in this course is
// produced by it and its noise floor decides what may be claimed. Then the two
// kinds of memory measurement, which is the trap the instrument exists to
// avoid. Then the hierarchy as a curve and the hierarchy as a set conflict,
// which are the same hardware seen from two sides. Then what a page and a
// store cost, which is where a program's own addresses start to matter. Then
// sharing, which is the one coherence-adjacent effect this machine can measure
// without a PMU. And last the harness, because the claim this course refuses to
// make is part of the course.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering The Memory Hierarchy pages...\n")

    var html = underlayer_content::render_mem_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Instrument
    html = underlayer_content::render_mem_instrument()
    fs::write_text_file("output/mem-instrument.html", html.data() as *u8, html.size())
    printf("  -> mem-instrument.html\n")

    html = underlayer_content::render_mem_latency()
    fs::write_text_file("output/mem-latency.html", html.data() as *u8, html.size())
    printf("  -> mem-latency.html\n")

    // Module 2: The Hierarchy
    html = underlayer_content::render_mem_hierarchy()
    fs::write_text_file("output/mem-hierarchy.html", html.data() as *u8, html.size())
    printf("  -> mem-hierarchy.html\n")

    html = underlayer_content::render_mem_associativity()
    fs::write_text_file("output/mem-associativity.html", html.data() as *u8, html.size())
    printf("  -> mem-associativity.html\n")

    // Module 3: What a Page and a Store Cost
    html = underlayer_content::render_mem_translation()
    fs::write_text_file("output/mem-translation.html", html.data() as *u8, html.size())
    printf("  -> mem-translation.html\n")

    html = underlayer_content::render_mem_writes()
    fs::write_text_file("output/mem-writes.html", html.data() as *u8, html.size())
    printf("  -> mem-writes.html\n")

    // Module 4: Sharing, and Verification
    html = underlayer_content::render_mem_sharing()
    fs::write_text_file("output/mem-sharing.html", html.data() as *u8, html.size())
    printf("  -> mem-sharing.html\n")

    html = underlayer_content::render_mem_verify()
    fs::write_text_file("output/mem-verify.html", html.data() as *u8, html.size())
    printf("  -> mem-verify.html\n")

    printf("Done: 8 concepts + landing page\n")
    return 0
}
