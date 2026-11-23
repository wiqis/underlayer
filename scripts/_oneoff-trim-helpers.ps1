# Remove the old writer-based send_* helpers and the duplicate
# apply_security_headers / redirect_to_login, now that responses.ch owns them.
$enc = New-Object System.Text.UTF8Encoding($false)

function Remove-Block([string]$path, [string]$startPattern, [string]$endPattern) {
    $t = [System.IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $start = [regex]::Match($t, $startPattern)
    if (-not $start.Success) { throw "start not found in $path : $startPattern" }
    $end = [regex]::Match($t.Substring($start.Index), $endPattern)
    if (-not $end.Success) { throw "end not found in $path : $endPattern" }
    $stop = $start.Index + $end.Index
    $t = $t.Substring(0, $start.Index) + $t.Substring($stop)
    [System.IO.File]::WriteAllText($path, $t, $enc)
    Write-Output "trimmed $path"
}

$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# helpers.ch: the four writer helpers sit at the top, up to `sv_to_string`.
Remove-Block (Join-Path $root 'helpers.ch') '    public func send_page' '    public func sv_to_string'

# pages_auth_gate.ch: redirect_to_login moved to responses.ch.
Remove-Block (Join-Path $root 'pages_auth_gate.ch') '    public func redirect_to_login' '^\}'

# security_headers.ch: drop the function, keep the rationale comment.
$p = Join-Path $root 'security_headers.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$idx = $t.IndexOf('public namespace underlayer_web {')
if ($idx -ge 0) {
    $head = $t.Substring(0, $idx)
    $tail = @'
// The headers themselves are set by `apply_security_headers` in `responses.ch`,
// next to the four functions that build a response.  The rationale above is why
// they are what they are; the code that sends them lives beside the code that
// sends the body so the two cannot drift apart.
'@
    [System.IO.File]::WriteAllText($p, $head + $tail.Replace("`r`n", "`n"), $enc)
    Write-Output 'security_headers.ch reduced to rationale'
}
