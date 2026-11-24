// Dynamic Linking and Shared Libraries â€” build entry point.
// Renders all 10 concept pages plus the landing page to output/.
//
// Concept order: the scope first (it is the central mechanism and nothing
// else works without it), then what a library contains, then loading one at
// run time, then rebuilding the scope by hand.

public func main() : int {
    course_writer::ensure_output()
    println(`Rendering Dynamic Linking pages...`)

    var html = underlayer_content::render_dyn_landing()
    course_writer::write_page("output/index.html", &html)
    println(`  -> index.html`)

    // Module 1: The Scope
    html = underlayer_content::render_dyn_scope()
    course_writer::write_page("output/dyn-scope.html", &html)
    println(`  -> dyn-scope.html`)

    html = underlayer_content::render_dyn_interpose()
    course_writer::write_page("output/dyn-interpose.html", &html)
    println(`  -> dyn-interpose.html`)

    html = underlayer_content::render_dyn_order_runtime()
    course_writer::write_page("output/dyn-order-runtime.html", &html)
    println(`  -> dyn-order-runtime.html`)

    // Module 2: Building a Library
    html = underlayer_content::render_dyn_build_so()
    course_writer::write_page("output/dyn-build-so.html", &html)
    println(`  -> dyn-build-so.html`)

    html = underlayer_content::render_dyn_export()
    course_writer::write_page("output/dyn-export.html", &html)
    println(`  -> dyn-export.html`)

    html = underlayer_content::render_dyn_symbolic()
    course_writer::write_page("output/dyn-symbolic.html", &html)
    println(`  -> dyn-symbolic.html`)

    // Module 3: Loading at Run Time
    html = underlayer_content::render_dyn_dlopen()
    course_writer::write_page("output/dyn-dlopen.html", &html)
    println(`  -> dyn-dlopen.html`)

    html = underlayer_content::render_dyn_bind_time()
    course_writer::write_page("output/dyn-bind-time.html", &html)
    println(`  -> dyn-bind-time.html`)

    html = underlayer_content::render_dyn_tls_block()
    course_writer::write_page("output/dyn-tls-block.html", &html)
    println(`  -> dyn-tls-block.html`)

    // Module 4: Rebuild It
    html = underlayer_content::render_dyn_resolve()
    course_writer::write_page("output/dyn-resolve.html", &html)
    println(`  -> dyn-resolve.html`)

    println(`Done: 10 concepts + landing page`)
    return 0
}
