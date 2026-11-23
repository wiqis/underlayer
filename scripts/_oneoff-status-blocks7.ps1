# Seventh pass: pages_help.ch and any remaining "var ct = ...; res.set_header..." block.
param([Parameter(Mandatory=$true)][string[]]$Paths)
$enc = New-Object System.Text.UTF8Encoding($false)
$total = 0
foreach ($p in $Paths) {
    $files = if (Test-Path -PathType Container $p) { Get-ChildItem -Path $p -Recurse -Filter *.ch -File } else { Get-Item $p }
    foreach ($f in $files) {
        if ($f.Name -eq 'responses.ch') { continue }
        $lines = [System.IO.File]::ReadAllLines($f.FullName)
        $out = New-Object System.Collections.ArrayList
        $i = 0; $changed = $false
        while ($i -lt $lines.Count) {
            $line = $lines[$i]
            # var ct = std::string_view(...)  followed by a header/write run
            $m = [regex]::Match($line, '^(\s*)var ct(_\w+)? = std::string_view\("(.*?)"\)\s*$')
            if ($m.Success) {
                $indent = $m.Groups[1].Value
                $ctype = $m.Groups[3].Value
                $j = $i + 1
                $runOk = $true
                $writeIdx = -1
                while ($j -lt $lines.Count -and ($lines[$j] -match '^\s*(?:res\.set_header_view|apply_security_headers\(res\)|var [A-Za-z_]\w* = |res\.write_view\(&\w+\))')) {
                    if ($lines[$j] -match '^\s*var (\w+) = ([A-Za-z_][\w\.]*)\.to_view\(\)') {
                        $viewVar = $Matches[1]; $srcVar = $Matches[2]
                    }
                    if ($lines[$j] -match '^\s*res\.write_view\(&(\w+)\)') { $writeIdx = $j; break }
                    $j++
                }
                if ($writeIdx -gt 0 -and $srcVar) {
                    $helper = if ($ctype -match 'application/json') { 'send_json_str' } else { 'send_html' }
                    [void]$out.Add("${indent}return underlayer_web::${helper}(&${srcVar})")
                    $i = $writeIdx + 1; $changed = $true; $total++
                    continue
                }
            }
            [void]$out.Add($line)
            $i++
        }
        if ($changed) { [System.IO.File]::WriteAllLines($f.FullName, $out, $enc) }
    }
}
Write-Output "seventh-pass blocks converted: $total"


