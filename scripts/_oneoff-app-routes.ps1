# Convert app/main.ch route closures from (req, res) to (req) => http::Response.
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")

# 1. Closures: drop the writer parameter.
$t = $t.Replace('(req, res) => {', '(req) => {')

# 2. Handler calls that ended by writing to `res` now return the response.
#    `underlayer_web::fn(args..., &raw mut res)` -> `return underlayer_web::fn(args...)`
$t = [regex]::Replace($t, '(underlayer_web::\w+)\(([^;\n]*?), &raw mut res\)', 'return $1($2)')

# 3. Rate-limit gates return Option<http::Response>.
$t = [regex]::Replace($t,
    'if\(!underlayer_web::(\w+)\(([^;\n]*?)\)\) \{ return \}',
    "var gate = underlayer_web::`$1(`$2)`n        if(gate is std::Option.Some) {`n            var Some(refusal) = gate else unsafe { unreachable }`n            return refusal`n        }")

# 4. Inline "400 + JSON error" blocks.
$t = [regex]::Replace($t,
    "            res\.status = 400u`n            var ct = std::string_view\(`"application/json`"\)`n            res\.set_header_view\(std::string_view\(`"Content-Type`"\), &ct\)`n            var body = std\.string\((.*?)`n            var bv = body\.to_view\(\)`n            res\.write_view\(&bv\)",
    "            var body = std.string(`$1`n            return underlayer_web::send_json_status(400u, &body)")

# 5. Plain "404 + text" blocks (lesson route, /u/:username).
$t = [regex]::Replace($t,
    "            res\.status = 404u`n            var ct = std::string_view\(`"text/plain`"\)`n            res\.set_header_view\(std::string_view\(`"Content-Type`"\), &ct\)`n            var body = std\.string\((.*?)`n            var bv = body\.to_view\(\)`n            res\.write_view\(&bv\)",
    "            var body = std.string(`$1`n            return underlayer_web::send_status_text(404u, &body)")

# 6. Auth pages gated by has_session already return the redirect.
$t = [regex]::Replace($t, 'return underlayer_web::redirect_to_login\((&raw mut res, )?&(\w+)\)', 'return underlayer_web::redirect_to_login(&$2)')

[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'app/main.ch routes converted'
Write-Output ('remaining &raw mut res: ' + (Select-String -Path $p -Pattern '&raw mut res' | Measure-Object).Count)
Write-Output ('remaining res.status: ' + (Select-String -Path $p -Pattern 'res\.status' | Measure-Object).Count)
