# Convert the static-page renderers to fill a caller-supplied HtmlPage, and drop
# the universal-runtime setup they do not need (they use no #universal component).
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

foreach ($name in @('pages_help.ch', 'pages_legal.ch')) {
    $p = Join-Path $root $name
    $t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")

    # `func render_x() : string {` + `var page = HtmlPage()`  ->  `func render_x(page : &mut HtmlPage) {`
    $t = [regex]::Replace($t, 'public func (render_\w+_page)\(\) : string \{\n\s*var page = HtmlPage\(\)\n',
                              'public func $1(page : &mut HtmlPage) {')
    # The universal runtime and the component theme are only needed by pages that
    # render a #universal component; these render none, so the page ships no JS.
    $t = $t -replace '(?m)^\s*page\.defaultUniversalSetup\(\)\n', ''
    $t = $t -replace '(?m)^\s*page\.injectDefaultComponentsTheme\(\)\n', ''
    # `return page.toString()` at the end of the renderer.
    $t = $t -replace '(?m)^\s*return page\.toString\(\)\n', ''

    [System.IO.File]::WriteAllText($p, $t, $enc)
}

Write-Output 'static renderers converted'
Select-String -Path (Join-Path $root 'pages_help.ch') -Pattern 'func render_help_page' | ForEach-Object { $_.Line.Trim() }
Select-String -Path (Join-Path $root 'pages_legal.ch') -Pattern 'func render_terms_page' | ForEach-Object { $_.Line.Trim() }
