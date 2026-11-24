# Page handlers for home + the three collection pages, and their App routes.
$enc = New-Object System.Text.UTF8Encoding($false)

# --- handlers_collection_pages.ch: three page handlers ---
$p = 'D:\Programming\Wiqis\Web\underlayer\web\src\handlers_collection_pages.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$start = $t.IndexOf('    // GET /courses')
if ($start -lt 0) { throw 'collection handler marker not found' }
$block = @'
    // GET /courses — the index.  Every lesson's back-link points here, so it is
    // the most-requested page in the collection.
    //
    // These three are `web::App` live routes: the framework renders the document
    // (asset URLs, cache headers, and the per-route chunk for their page JS), and
    // each function only fills the page.
    public func page_courses(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        var courses_dir = request_courses_dir()
        render_courses_page(page, &courses_dir)
    }

    // GET /learning-path — the three routes in full.
    public func page_learning_path(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        var courses_dir = request_courses_dir()
        render_learning_path_page_index(page, &courses_dir)
    }

    // GET /search — concept search.  Results are server-rendered from the `q`
    // query parameter, so the page works with JavaScript disabled and the URL is
    // shareable.
    public func page_search(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        var courses_dir = request_courses_dir()
        var query = string()
        var got = ctx.query("q")
        if(got is std::Option.Some) {
            var Some(v) = got else unsafe { unreachable }
            query.append_view(&v)
        }
        render_search_page(page, &courses_dir, &query)
    }

}
'@.Replace("`r`n", "`n")
$t = $t.Substring(0, $start) + $block
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- app/main.ch: drop the four old routes, add the App routes ---
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")

$homeRoute = @'
    // Home page
    srv.router.add("GET", "/", ||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
'@.Replace("`r`n","`n")
if (-not $t.Contains($homeRoute)) { throw 'home route not found' }
$t = $t.Replace($homeRoute, '    // Home page: a web::App live route (see the App below).')

$courses = @'
    srv.router.add("GET", "/courses", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::deliver(&req, underlayer_web::handle_courses_page(&courses_dir, &req))
    })
'@.Replace("`r`n","`n")
if (-not $t.Contains($courses)) { throw 'courses route not found' }
$t = $t.Replace($courses, '    // /courses: a web::App live route (see the App below).')

$lp = @'
    srv.router.add("GET", "/learning-path", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::deliver(&req, underlayer_web::handle_learning_path_index(&courses_dir, &req))
    })
'@.Replace("`r`n","`n")
if (-not $t.Contains($lp)) { throw 'learning-path route not found' }
$t = $t.Replace($lp, '    // /learning-path: a web::App live route (see the App below).')

$search = @'
    srv.router.add("GET", "/search", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::deliver(&req, underlayer_web::handle_search_page(&courses_dir, &req))
    })
'@.Replace("`r`n","`n")
if (-not $t.Contains($search)) { throw 'search route not found' }
$t = $t.Replace($search, '    // /search: a web::App live route (see the App below).')

# Register them on the App, next to the pre-rendered pages.
$t = $t.Replace('    app.not_found(underlayer_web::page_not_found)',
@'
    app.not_found(underlayer_web::page_not_found)
    // Per-request pages. `no-store` is the honest policy: these renders carry the
    // reader's own state (nav, enrol button, onboarding banner), so a shared cache
    // must not keep them. `set_dynamic_gzip` compresses them on the way out.
    app.live("/", underlayer_web::page_home)
    app.live("/courses", underlayer_web::page_courses)
    app.live("/learning-path", underlayer_web::page_learning_path)
    app.live("/search", underlayer_web::page_search)
    app.set_dynamic_gzip(true)
'@.Replace("`r`n","`n"))

[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'live routes registered'

