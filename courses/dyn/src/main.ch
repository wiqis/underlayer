// Dynamic Linking and Shared Libraries — build entry point.
// Renders all 10 concept pages plus the landing page to output/.
//
// Concept order: the scope first (it is the central mechanism and nothing
// else works without it), then what a library contains, then loading one at
// run time, then rebuilding the scope by hand.

public func main() : int {
    fs::mkdir("output")
    printf("Rendering Dynamic Linking pages...\n")

    var html = underlayer_content::render_dyn_landing()
    fs::write_text_file("output/index.html", html.data() as *u8, html.size())
    printf("  -> index.html\n")

    // Module 1: The Scope
    html = underlayer_content::render_dyn_scope()
    fs::write_text_file("output/dyn-scope.html", html.data() as *u8, html.size())
    printf("  -> dyn-scope.html\n")

    html = underlayer_content::render_dyn_interpose()
    fs::write_text_file("output/dyn-interpose.html", html.data() as *u8, html.size())
    printf("  -> dyn-interpose.html\n")

    html = underlayer_content::render_dyn_order_runtime()
    fs::write_text_file("output/dyn-order-runtime.html", html.data() as *u8, html.size())
    printf("  -> dyn-order-runtime.html\n")

    // Module 2: Building a Library
    html = underlayer_content::render_dyn_build_so()
    fs::write_text_file("output/dyn-build-so.html", html.data() as *u8, html.size())
    printf("  -> dyn-build-so.html\n")

    html = underlayer_content::render_dyn_export()
    fs::write_text_file("output/dyn-export.html", html.data() as *u8, html.size())
    printf("  -> dyn-export.html\n")

    html = underlayer_content::render_dyn_symbolic()
    fs::write_text_file("output/dyn-symbolic.html", html.data() as *u8, html.size())
    printf("  -> dyn-symbolic.html\n")

    // Module 3: Loading at Run Time
    html = underlayer_content::render_dyn_dlopen()
    fs::write_text_file("output/dyn-dlopen.html", html.data() as *u8, html.size())
    printf("  -> dyn-dlopen.html\n")

    html = underlayer_content::render_dyn_bind_time()
    fs::write_text_file("output/dyn-bind-time.html", html.data() as *u8, html.size())
    printf("  -> dyn-bind-time.html\n")

    html = underlayer_content::render_dyn_tls_block()
    fs::write_text_file("output/dyn-tls-block.html", html.data() as *u8, html.size())
    printf("  -> dyn-tls-block.html\n")

    // Module 4: Rebuild It
    html = underlayer_content::render_dyn_resolve()
    fs::write_text_file("output/dyn-resolve.html", html.data() as *u8, html.size())
    printf("  -> dyn-resolve.html\n")

    printf("Done: 10 concepts + landing page\n")
    return 0
}
