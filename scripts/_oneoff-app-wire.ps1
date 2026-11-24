# Wire web::App into main.ch: the six static pages become pre-rendered App routes,
# the App is served through one catch-all, and the asset prefix is reserved.
$enc = New-Object System.Text.UTF8Encoding($false)
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")

# 1. Remove the six /help-style routes: the App answers them now.
$old = @'
    // ---- Help & Guide Pages ----
    srv.router.add("GET", "/help", ||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_help_page(&req))
    })
    srv.router.add("GET", "/shortcuts", ||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_shortcuts_page(&req))
    })
    srv.router.add("GET", "/faq", ||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_faq_page(&req))
    })
    srv.router.add("GET", "/about", ||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_about_page(&req))
    })
    srv.router.add("GET", "/terms", ||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_terms_page(&req))
    })
    srv.router.add("GET", "/privacy", ||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_privacy_page(&req))
    })
'@.Replace("`r`n", "`n")
if (-not $t.Contains($old)) { throw 'help routes block not found' }
$t = $t.Replace($old, '    // ---- Help & Guide Pages: served by the web::App as pre-rendered routes (see the App below) ----')

# 2. Build the App right before the server starts, and route everything through it.
$marker = '    // ---- Start server ----'
if (-not $t.Contains($marker)) { throw 'start-server marker not found' }

$app_block = @'
    // ---- Delivery: one web::App owns the page layer ----
    //
    // WHY AN APP AND NOT ONE ROUTE PER PAGE.  The six guide pages are the same for
    // every reader, so they are PRE-RENDERED (`app.page`): `build()` renders each
    // one once, minifies its inline CSS, moves its page JS into a content-hashed
    // per-route chunk (`assets/chunk.<hash>.js`), writes a `.gz` sibling, and the
    // framework serves the frozen bytes with `no-cache` + ETag + 304.  A request
    // for /help runs no handler at all.
    //
    // Everything else stays per-request, and keeps the response it already built.
    // The App is mounted behind one catch-all, so the 183 routes registered above
    // keep their exact URLs and their dispatch order; the App only ever sees what
    // they did not claim (/help-style pages, /assets/*, and the 404).
    //
    // `set_minify` shrinks the emitted chunks, `set_gzip` precompresses the frozen
    // artifacts (the honest `Accept-Encoding` negotiation lives in the site), and
    // `finish()` is what actually writes them — `build()` only compiles.
    var app = web::App.make("build/site", "app", "assets")
    app.set_minify(true)
    app.set_gzip(true)
    app.page("/help", underlayer_web::page_help)
    app.page("/shortcuts", underlayer_web::page_shortcuts)
    app.page("/faq", underlayer_web::page_faq)
    app.page("/about", underlayer_web::page_about)
    app.page("/terms", underlayer_web::page_terms)
    app.page("/privacy", underlayer_web::page_privacy)
    if(!app.build()) {
        var build_err = std::string("[underlayer] web::App build failed: ")
        var err_view = app.error_message()
        build_err.append_view(&err_view)
        underlayer_core::log_line(&build_err)
        return 1
    }
    if(!app.finish()) {
        var finish_err = std::string("[underlayer] web::App could not write build/site")
        underlayer_core::log_line(&finish_err)
        return 1
    }
    unsafe { web::install(&raw mut app) }
    // The catch-all: one registration per method, last in the table, so every
    // explicit route above keeps first refusal. `web::serve_request` answers from
    // the frozen site (pages, assets with their immutable cache headers, 404).
    srv.router.add("GET", "/:path*", ||(req) => {
        return web::serve_request(req)
    })
    srv.router.add("HEAD", "/:path*", ||(req) => {
        return web::serve_request(req)
    })

'@.Replace("`r`n", "`n")
$t = $t.Replace($marker, $app_block + $marker)

[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'app wired'
