# Convert the web layer from ResponseWriter to returned http::Response.
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'
$enc = New-Object System.Text.UTF8Encoding($false)
$changed = 0

foreach ($f in Get-ChildItem -Path $root -Recurse -Filter *.ch -File) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    $orig = $t

    # 1. Handler signatures: drop `res` and return a response.
    $t = $t -replace ', res : \*mut http::ResponseWriter\)', ') : http::Response'
    $t = $t -replace '\(req : &http::Request, res : \*mut http::ResponseWriter\)', '(req : &http::Request) : http::Response'
    $t = $t -replace '\(req : \*mut http::Request, res : \*mut http::ResponseWriter\)', '(req : *mut http::Request) : http::Response'
    $t = $t -replace 'res : \*mut http::ResponseWriter\)', ') : http::Response'

    # 2. Send helpers become returned responses.
    $t = [regex]::Replace($t, 'send_json_str\(res, &raw ([A-Za-z_][\w\.\(\)]*)\)', 'return send_json_str(&$1)')
    $t = [regex]::Replace($t, 'send_json_str\(res, &([A-Za-z_][\w\.\(\)]*)\)', 'return send_json_str(&$1)')
    $t = [regex]::Replace($t, 'send_error\(res, ([0-9]+u), &raw ([A-Za-z_][\w\.\(\)]*)\)', 'return send_error($1, &$2)')
    $t = [regex]::Replace($t, 'send_error\(res, ([0-9]+u), &([A-Za-z_][\w\.\(\)]*)\)', 'return send_error($1, &$2)')
    $t = [regex]::Replace($t, 'send_html\(res, &raw ([A-Za-z_][\w\.\(\)]*)\)', 'return send_html(&$1)')
    $t = [regex]::Replace($t, 'send_html\(res, &([A-Za-z_][\w\.\(\)]*)\)', 'return send_html(&$1)')
    $t = [regex]::Replace($t, 'send_page\(res, &raw ([A-Za-z_][\w\.\(\)]*)\)', 'return send_page(&$1)')
    $t = [regex]::Replace($t, 'send_page\(res, &([A-Za-z_][\w\.\(\)]*)\)', 'return send_page(&$1)')
    $t = [regex]::Replace($t, 'redirect_to_login\(&raw mut res, &raw ([A-Za-z_][\w\.\(\)]*)\)', 'return redirect_to_login(&$1)')
    $t = [regex]::Replace($t, 'redirect_to_login\(&raw mut res, &([A-Za-z_][\w\.\(\)]*)\)', 'return redirect_to_login(&$1)')

    if ($t -ne $orig) {
        [System.IO.File]::WriteAllText($f.FullName, $t, $enc)
        $changed++
    }
}
Write-Output "handlers converted in $changed files"
Write-Output ("remaining ResponseWriter: " + (Select-String -Path (Join-Path $root '*.ch') -Pattern 'ResponseWriter' | Measure-Object).Count)
