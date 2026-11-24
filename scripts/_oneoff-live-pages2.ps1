# Convert the three collection renderers to fill a caller-supplied page.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# Each renderer: `func render_X(args) : string {` ... `var page = HtmlPage()` ... `return page.toString()`
# becomes `func render_X(page : &mut HtmlPage, args) {` ... (page given) ... (nothing).
$jobs = @(
  @{ file = 'pages_courses.ch'; sig = '    public func render_courses_page(courses_dir : &string) : string {' },
  @{ file = 'pages_path.ch';    sig = '    public func render_learning_path_page_index(courses_dir : &string) : string {' },
  @{ file = 'pages_search.ch';  sig = '    public func render_search_page(courses_dir : &string, query : &string) : string {' }
)

foreach ($job in $jobs) {
    $p = Join-Path $root $job.file
    $t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
    $sig = $job.sig
    if (-not $t.Contains($sig)) { throw "signature not found in $($job.file): $sig" }
    # Rearrange the parameter list so the page comes first.
    $new = $sig -replace '\(', '(page : &mut HtmlPage, ' -replace '\(page : &mut HtmlPage, \)', '(page : &mut HtmlPage)'
    $t = $t.Replace($sig, $new)
    # The universal runtime is the framework's job (it adds it only when a page uses
    # a component); the component theme stays because these pages use its tokens.
    $t = $t -replace '(?m)^\s*var page = HtmlPage\(\)\n', ''
    $t = $t -replace '(?m)^\s*page\.defaultUniversalSetup\(\)\n', ''
    $t = $t -replace '(?m)^\s*return page\.toString\(\)\n', ''
    [System.IO.File]::WriteAllText($p, $t, $enc)
    Write-Output ("converted " + $job.file)
}
