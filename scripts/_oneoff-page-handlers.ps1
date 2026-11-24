# Replace the six static-page handlers with page handlers the framework calls
# (ctx, page) — pre-rendered route bodies, no response of their own.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# --- pages_help.ch: 4 handlers -> 4 page handlers ---
$p = Join-Path $root 'pages_help.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$start = $t.IndexOf('    // ---- Handler functions ----')
if ($start -lt 0) { throw 'help handler marker not found' }
$block = @'
    // ---- Page handlers ----
    //
    // These four are PRE-RENDERED routes: `web::App.page` calls each one once, in
    // `build()`, and the result is frozen with a content-hashed style/script
    // chunk, a gzip sibling and an ETag. A request for /help never runs this
    // code again. That is why they take the site's page and return nothing: the
    // framework owns the document, the asset URLs and the cache headers.
    public func page_help(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        render_help_page(page)
    }

    public func page_shortcuts(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        render_shortcuts_page(page)
    }

    public func page_faq(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        render_faq_page(page)
    }

    public func page_about(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        render_about_page(page)
    }

}
'@
$t = $t.Substring(0, $start) + $block.Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- pages_legal.ch: 2 handlers -> 2 page handlers ---
$p = Join-Path $root 'pages_legal.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$start = $t.IndexOf('    public func handle_terms_page(')
if ($start -lt 0) { throw 'legal handler marker not found' }
$block = @'
    // Pre-rendered routes (see pages_help.ch): the framework renders once at
    // build time and serves the frozen artifact.
    public func page_terms(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        render_terms_page(page)
    }

    public func page_privacy(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        render_privacy_page(page)
    }

}
'@
$t = $t.Substring(0, $start) + $block.Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'page handlers written'
