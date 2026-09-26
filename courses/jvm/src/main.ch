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

    // Module 2: Members and Code
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

    // Module 3: The Attribute Mechanism
    html = underlayer_content::render_jvm_attributes()
    fs::write_text_file("output/jvm-attributes.html", html.data() as *u8, html.size())
    printf("  -> jvm-attributes.html\n")

    html = underlayer_content::render_jvm_inner_classes()
    fs::write_text_file("output/jvm-inner-classes.html", html.data() as *u8, html.size())
    printf("  -> jvm-inner-classes.html\n")

    html = underlayer_content::render_jvm_signatures()
    fs::write_text_file("output/jvm-signatures.html", html.data() as *u8, html.size())
    printf("  -> jvm-signatures.html\n")

    html = underlayer_content::render_jvm_annotations()
    fs::write_text_file("output/jvm-annotations.html", html.data() as *u8, html.size())
    printf("  -> jvm-annotations.html\n")

    // Module 4: Object Shapes
    html = underlayer_content::render_jvm_records()
    fs::write_text_file("output/jvm-records.html", html.data() as *u8, html.size())
    printf("  -> jvm-records.html\n")

    html = underlayer_content::render_jvm_sealed()
    fs::write_text_file("output/jvm-sealed.html", html.data() as *u8, html.size())
    printf("  -> jvm-sealed.html\n")

    html = underlayer_content::render_jvm_enums()
    fs::write_text_file("output/jvm-enums.html", html.data() as *u8, html.size())
    printf("  -> jvm-enums.html\n")

    // Module 5: Linking and Versioning
    html = underlayer_content::render_jvm_invokedynamic()
    fs::write_text_file("output/jvm-invokedynamic.html", html.data() as *u8, html.size())
    printf("  -> jvm-invokedynamic.html\n")

    html = underlayer_content::render_jvm_modules()
    fs::write_text_file("output/jvm-modules.html", html.data() as *u8, html.size())
    printf("  -> jvm-modules.html\n")

    html = underlayer_content::render_jvm_versions()
    fs::write_text_file("output/jvm-versions.html", html.data() as *u8, html.size())
    printf("  -> jvm-versions.html\n")

    // Landing page
    html = underlayer_content::render_jvm_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    printf("JVM Class File Format: 18 concepts + landing page generated in output/\n")
    return 0
}
