# The App owns the catch-all and the 404: drop the hand-written /:path* 404 route,
# and give the App a page handler for its not-found slot.
$enc = New-Object System.Text.UTF8Encoding($false)

# --- app/main.ch: remove the old 404 catch-all ---
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$old = @'
    // ---- 404 ----
    // The catch-all is LAST: every earlier route gets first refusal, and anything
    // unmatched lands on a real page instead of the router's bare "Not found".
    srv.router.add("GET", "/:path*", ||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::not_found_page(&req))
    })

'@.Replace("`r`n", "`n")
if (-not $t.Contains($old)) { throw 'old 404 route not found' }
$t = $t.Replace($old, '')

# Register the App's own 404 next to its pages.
$t = $t.Replace('    app.page("/privacy", underlayer_web::page_privacy)',
                '    app.page("/privacy", underlayer_web::page_privacy)' + "`n" + '    app.not_found(underlayer_web::page_not_found)')
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- responses.ch: not_found becomes a page handler ---
$p = 'D:\Programming\Wiqis\Web\underlayer\web\src\responses.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$start = $t.IndexOf('    // A 404 page, for the catch-all route at the end of the table.')
if ($start -lt 0) { throw 'not_found block not found' }
$block = @'
    // The 404 page, as the App's `not_found` slot.
    //
    // It is a live route: the address a reader mistyped is the one thing that
    // varies, so the page is rendered per request and carries `no-store`, like
    // every other per-request render.
    public func page_not_found(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        page.defaultPrepare()
        var wanted = ctx.path()
        #html {
            <main class="container" id="main-content">
                <h1>That page is not here</h1>
                <p>The address <code>{wanted}</code> does not match a course, a lesson or a page on this platform.</p>
                <p><a href="/courses">Browse the courses</a> &middot; <a href="/">Home</a> &middot; <a href="/search">Search</a></p>
            </main>
        }
        #css {
            body { margin: 0; font-family: system-ui, sans-serif; line-height: 1.6; color: #111827; background: #ffffff; }
            .container { max-width: 40rem; margin: 0 auto; padding: 4rem 1.5rem; }
            h1 { font-size: 1.5rem; margin: 0 0 0.75rem; }
            code { background: #f3f4f6; padding: 0.1rem 0.3rem; border-radius: 3px; }
            a { color: #2563eb; }
        }
    }

}
'@.Replace("`r`n", "`n")
$t = $t.Substring(0, $start) + $block
[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output '404 moved onto the App'
