# Restore the four per-request routes as endpoints in app/main.ch, and drop the
# app.live registrations.
$enc = New-Object System.Text.UTF8Encoding($false)
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")

$live = @'
    app.live("/", underlayer_web::page_home)
    app.live("/courses", underlayer_web::page_courses)
    app.live("/learning-path", underlayer_web::page_learning_path)
    app.live("/search", underlayer_web::page_search)
'@.Replace("`r`n","`n")
if (-not $t.Contains($live)) { throw 'app.live block not found' }
$t = $t.Replace($live, '')

# Put the four routes back where they were, as endpoints.
$t = $t.Replace('    // Home page: a web::App live route (see the App below).',
@'
    // Home page — a per-request response (see the note on handle_home).
    srv.router.add("GET", "/", ||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
'@.Replace("`r`n","`n"))

$t = $t.Replace('    // /courses: a web::App live route (see the App below).',
@'
    // /courses — the collection index.
    srv.router.add("GET", "/courses", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver(&req, underlayer_web::handle_courses_page(&courses_dir, &req))
    })
'@.Replace("`r`n","`n"))

$t = $t.Replace('    // /learning-path: a web::App live route (see the App below).',
@'
    // /learning-path — the three routes in full.
    srv.router.add("GET", "/learning-path", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver(&req, underlayer_web::handle_learning_path_index(&courses_dir, &req))
    })
'@.Replace("`r`n","`n"))

$t = $t.Replace('    // /search: a web::App live route (see the App below).',
@'
    // /search — server-rendered from ?q=.
    srv.router.add("GET", "/search", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver(&req, underlayer_web::handle_search_page(&courses_dir, &req))
    })
'@.Replace("`r`n","`n"))

[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'endpoints restored'
