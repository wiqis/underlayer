// JVM Class File Format - Build entry point
// Renders all concept pages to output/ directory.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering JVM Class File Format pages...`)

    // Module 1: The Container
    var html = underlayer_content::render_jvm_intro()
    course_writer::write_page("output/jvm-intro.html", &html)
    println(`  -> jvm-intro.html`)

    html = underlayer_content::render_jvm_header()
    course_writer::write_page("output/jvm-header.html", &html)
    println(`  -> jvm-header.html`)

    html = underlayer_content::render_jvm_constant_pool()
    course_writer::write_page("output/jvm-constant-pool.html", &html)
    println(`  -> jvm-constant-pool.html`)

    html = underlayer_content::render_jvm_strings()
    course_writer::write_page("output/jvm-strings.html", &html)
    println(`  -> jvm-strings.html`)

    // Module 2: Members and Code
    html = underlayer_content::render_jvm_members()
    course_writer::write_page("output/jvm-members.html", &html)
    println(`  -> jvm-members.html`)

    html = underlayer_content::render_jvm_code()
    course_writer::write_page("output/jvm-code.html", &html)
    println(`  -> jvm-code.html`)

    html = underlayer_content::render_jvm_branches()
    course_writer::write_page("output/jvm-branches.html", &html)
    println(`  -> jvm-branches.html`)

    html = underlayer_content::render_jvm_stackmaps()
    course_writer::write_page("output/jvm-stackmaps.html", &html)
    println(`  -> jvm-stackmaps.html`)

    // Module 3: The Attribute Mechanism
    html = underlayer_content::render_jvm_attributes()
    course_writer::write_page("output/jvm-attributes.html", &html)
    println(`  -> jvm-attributes.html`)

    html = underlayer_content::render_jvm_inner_classes()
    course_writer::write_page("output/jvm-inner-classes.html", &html)
    println(`  -> jvm-inner-classes.html`)

    html = underlayer_content::render_jvm_signatures()
    course_writer::write_page("output/jvm-signatures.html", &html)
    println(`  -> jvm-signatures.html`)

    html = underlayer_content::render_jvm_annotations()
    course_writer::write_page("output/jvm-annotations.html", &html)
    println(`  -> jvm-annotations.html`)

    // Module 4: Object Shapes
    html = underlayer_content::render_jvm_records()
    course_writer::write_page("output/jvm-records.html", &html)
    println(`  -> jvm-records.html`)

    html = underlayer_content::render_jvm_sealed()
    course_writer::write_page("output/jvm-sealed.html", &html)
    println(`  -> jvm-sealed.html`)

    html = underlayer_content::render_jvm_enums()
    course_writer::write_page("output/jvm-enums.html", &html)
    println(`  -> jvm-enums.html`)

    // Module 5: Linking and Versioning
    html = underlayer_content::render_jvm_invokedynamic()
    course_writer::write_page("output/jvm-invokedynamic.html", &html)
    println(`  -> jvm-invokedynamic.html`)

    html = underlayer_content::render_jvm_modules()
    course_writer::write_page("output/jvm-modules.html", &html)
    println(`  -> jvm-modules.html`)

    html = underlayer_content::render_jvm_versions()
    course_writer::write_page("output/jvm-versions.html", &html)
    println(`  -> jvm-versions.html`)

    // Landing page
    html = underlayer_content::render_jvm_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    println(`JVM Class File Format: 18 concepts + landing page generated in output/`)
    return 0
}
