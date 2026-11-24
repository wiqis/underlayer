# Convert home + the three collection pages to web::App live routes.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# --- handlers_home.ch: handle_home becomes a page handler ---
$p = Join-Path $root 'handlers_home.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
    public func handle_home(req : &http::Request) : http::Response {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
'@.Replace("`r`n","`n"),
@'
    // GET / — a `web::App` live route: the framework owns the document, the asset
    // URLs and the cache headers; this function only fills the page.
    public func page_home(ctx : &mut web::RequestContext, page : &mut HtmlPage) {
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
'@.Replace("`r`n","`n"))
$t = $t.Replace('        return send_page(&page)', '')
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- pages_courses.ch / pages_path.ch / pages_search.ch: renderers fill a page ---
foreach ($name in @('pages_courses.ch', 'pages_path.ch', 'pages_search.ch')) {
    $p = Join-Path $root $name
    $t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
    $t = [regex]::Replace($t, 'public func (render_courses_page|render_learning_path_page_index|render_search_page)\(([^)]*)\) : string \{\n\s*var page = HtmlPage\(\)\n',
                              'public func $1(page : &mut HtmlPage, $2) {')
    $t = [regex]::Replace($t, 'public func render_courses_page\(courses_dir : &string\) : string \{\n\s*var page = HtmlPage\(\)\n',
                              'public func render_courses_page(page : &mut HtmlPage, courses_dir : &string) {')
    [System.IO.File]::WriteAllText($p, $t, $enc)
}
Write-Output 'renderers touched'
Select-String -Path (Join-Path $root 'pages_courses.ch') -Pattern 'func render_courses_page' | ForEach-Object { $_.Line.Trim() }
Select-String -Path (Join-Path $root 'pages_path.ch') -Pattern 'func render_learning_path_page_index' | ForEach-Object { $_.Line.Trim() }
Select-String -Path (Join-Path $root 'pages_search.ch') -Pattern 'func render_search_page' | ForEach-Object { $_.Line.Trim() }
