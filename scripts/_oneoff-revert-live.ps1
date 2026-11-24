# Revert the four per-request pages from `app.live` back to endpoints.
#
# MEASURED, not a preference: a `live` render attaches the page to the site's
# FROZEN asset sink, so every `#css` block and the component theme go into the
# shared sink and are dropped when the sink is already frozen — the served home
# page came back with no <style> at all and no <link> to the shared bundle, i.e.
# an unstyled page. Those pages carry their own large stylesheets, so they stay
# per-request endpoints (their `deliver` layer gives gzip + cache policy) until
# their CSS is served from a hashed bundle the page actually links.
$enc = New-Object System.Text.UTF8Encoding($false)

# --- handlers_home.ch: back to a response ---
$p = 'D:\Programming\Wiqis\Web\underlayer\web\src\handlers_home.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
    // GET / — a `web::App` live route: the framework owns the document, the asset
    // URLs and the cache headers; this function only fills the page.
    public func page_home(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        page.defaultPrepare()
'@.Replace("`r`n","`n"),
@'
    // GET / — a per-request page. It stays an endpoint rather than an
    // `app.live` route: see the note in handlers_collection_pages.ch.
    public func handle_home(req : &http::Request) : http::Response {
        var page = HtmlPage()
        page.defaultPrepare()
'@.Replace("`r`n","`n"))
$t = $t.Replace("        render_home_search_js(page)`n", "        render_home_search_js(&mut page)`n        return send_page(&page)`n")
$t = $t.Replace("        render_home_search_js(page)`n", "        render_home_search_js(&mut page)`n        return send_page(&page)`n")
$t = $t.Replace("        render_session_js(page)", "        render_session_js(&mut page)")
# The page-local helpers now take the local page again.
$t = $t.Replace("render_nav_bar(page)", "render_nav_bar(&mut page)")
$t = $t.Replace("render_onboarding_gate(page)", "render_onboarding_gate(&mut page)")
$t = $t.Replace("render_home_search_js(page)", "render_home_search_js(&mut page)")
$t = $t.Replace("render_session_js(page)", "render_session_js(&mut page)")
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- collection pages: back to response handlers ---
$p = 'D:\Programming\Wiqis\Web\underlayer\web\src\handlers_collection_pages.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$start = $t.IndexOf('    // GET /courses')
if ($start -lt 0) { throw 'collection marker not found' }
$block = @'
    // Three per-request pages, kept as endpoints rather than `app.live` routes.
    //
    // MEASURED: an `app.live` render attaches the page to the site's FROZEN asset
    // sink, so the page's `#css` blocks and the component theme are written to a
    // sink that is already closed — the served home page came back with no
    // <style> and no <link>, i.e. unstyled. These pages carry their own large
    // stylesheets, so the correct shape for them is a full response, cached
    // `no-cache` with an ETag and gzipped by `deliver`.
    public func handle_courses_page(courses_dir : &string, req : &http::Request) : http::Response {
        var page = HtmlPage()
        render_courses_page(&mut page, courses_dir)
        var html = page.toString()
        return send_html(&html)
    }

    public func handle_learning_path_index(courses_dir : &string, req : &http::Request) : http::Response {
        var page = HtmlPage()
        render_learning_path_page_index(&mut page, courses_dir)
        var html = page.toString()
        return send_html(&html)
    }

    public func handle_search_page(courses_dir : &string, req : &http::Request) : http::Response {
        var q_key = string("q")
        var q_v = sv_or_empty(req.query.get(std::str.make_key_view(&q_key)))
        var query = sv_to_string(&q_v)
        var page = HtmlPage()
        render_search_page(&mut page, courses_dir, &query)
        var html = page.toString()
        return send_html(&html)
    }

}
'@.Replace("`r`n", "`n")
$t = $t.Substring(0, $start) + $block
[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'collection handlers restored'
