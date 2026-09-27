// Executable Security and Hardening — build entry point.
// Renders all 7 concept pages plus the landing page to output/.
//
// Concept order: the defaults first, because the compiler disagreement is the
// argument for the course; then the two features that leave a trace in the
// file's geometry; then the two that are about permissions; then the reader.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Executable Security pages...\n")

    var html = underlayer_content::render_sec_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Defaults
    html = underlayer_content::render_sec_defaults()
    fs::write_text_file("output/sec-defaults.html", html.data() as *u8, html.size())
    printf("  -> sec-defaults.html\n")

    html = underlayer_content::render_sec_canary()
    fs::write_text_file("output/sec-canary.html", html.data() as *u8, html.size())
    printf("  -> sec-canary.html\n")

    // Module 2: The GOT
    html = underlayer_content::render_sec_relro()
    fs::write_text_file("output/sec-relro.html", html.data() as *u8, html.size())
    printf("  -> sec-relro.html\n")

    html = underlayer_content::render_sec_fortify()
    fs::write_text_file("output/sec-fortify.html", html.data() as *u8, html.size())
    printf("  -> sec-fortify.html\n")

    // Module 3: Permissions
    html = underlayer_content::render_sec_wx()
    fs::write_text_file("output/sec-wx.html", html.data() as *u8, html.size())
    printf("  -> sec-wx.html\n")

    html = underlayer_content::render_sec_cet()
    fs::write_text_file("output/sec-cet.html", html.data() as *u8, html.size())
    printf("  -> sec-cet.html\n")

    // Module 4: Read It Yourself
    html = underlayer_content::render_sec_posture()
    fs::write_text_file("output/sec-posture.html", html.data() as *u8, html.size())
    printf("  -> sec-posture.html\n")

    printf("Done: 7 concepts + landing page\n")
    return 0
}
