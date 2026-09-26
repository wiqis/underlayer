// JVM Class File Format - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering JVM Class File Format pages...\n")

    // Module 1: The Container
    var html = underlayer_content::render_jvm_intro()
    fs::write_text_file("output/jvm-intro.html", html.data() as *u8, html.size())
    printf("  -> jvm-intro.html\n")

    html = underlayer_content::render_jvm_header()
    fs::write_text_file("output/jvm-header.html", html.data() as *u8, html.size())
    printf("  -> jvm-header.html\n")

    html = underlayer_content::render_jvm_constant_pool()
    fs::write_text_file("output/jvm-constant-pool.html", html.data() as *u8, html.size())
    printf("  -> jvm-constant-pool.html\n")

    html = underlayer_content::render_jvm_strings()
    fs::write_text_file("output/jvm-strings.html", html.data() as *u8, html.size())
    printf("  -> jvm-strings.html\n")

    html = underlayer_content::render_jvm_members()
    fs::write_text_file("output/jvm-members.html", html.data() as *u8, html.size())
    printf("  -> jvm-members.html\n")

    html = underlayer_content::render_jvm_code()
    fs::write_text_file("output/jvm-code.html", html.data() as *u8, html.size())
    printf("  -> jvm-code.html\n")

    html = underlayer_content::render_jvm_branches()
    fs::write_text_file("output/jvm-branches.html", html.data() as *u8, html.size())
    printf("  -> jvm-branches.html\n")

    html = underlayer_content::render_jvm_stackmaps()
    fs::write_text_file("output/jvm-stackmaps.html", html.data() as *u8, html.size())
    printf("  -> jvm-stackmaps.html\n")

    // Landing page
    html = underlayer_content::render_jvm_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("JVM Class File Format: 8 concepts + landing page generated in output/\n")
    return 0
}
