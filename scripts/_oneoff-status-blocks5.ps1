# Fifth pass: header run that includes apply_security_headers(res), then a write.
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
            if ($line -match '^\s*res\.(set_header_view|status)\b') {
                $start = $i
                $j = $i
                $ct = ''
                $status = ''
                $extra = $false
                while ($j -lt $lines.Count -and $lines[$j] -match '^\s*(res\.(set_header_view|status)\b|apply_security_headers\(res\))') {
                    if ($lines[$j] -match 'res\.status = (\d+)u') { $status = $Matches[1] }
                    if ($lines[$j] -match 'Content-Type') {
                        if ($lines[$j] -match 'application/json') { $ct = 'json' }
                        elseif ($lines[$j] -match 'text/html') { $ct = 'html' }
                        elseif ($lines[$j] -match 'text/plain') { $ct = 'text' }
                    } elseif ($lines[$j] -match 'set_header_view' -and $lines[$j] -notmatch 'Content-Type') {
                        $extra = $true
                    }
                    $j++
                }
                if ($j -lt $lines.Count -and $lines[$j] -match '^\s*res\.write_view\(&(\w+)\)') {
                    $viewVar = $Matches[1]
                    $src = $null
                    for ($k = $start - 1; $k -ge 0 -and $k -ge $start - 40; $k--) {
                        if ($lines[$k] -match ('var ' + [regex]::Escape($viewVar) + ' = ([A-Za-z_][\w\.]*)\.to_view\(\)')) {
                            $src = $Matches[1]; break
                        }
                    }
                    if ($src -and -not $extra) {
                        $indent = '            '
                        if ($line -match '^(\s*)') { $indent = $Matches[1] }
                        if ($ct -eq 'json') {
                            if ($status) { [void]$out.Add("${indent}return underlayer_web::send_json_status(${status}u, &$src)") }
                            else { [void]$out.Add("${indent}return underlayer_web::send_json_str(&$src)") }
                        } elseif ($ct -eq 'text') {
                            if ($status) { [void]$out.Add("${indent}return underlayer_web::send_status_text(${status}u, &$src)") }
                            else { [void]$out.Add("${indent}return underlayer_web::send_status_text(200u, &$src)") }
                        } else {
                            [void]$out.Add("${indent}return underlayer_web::send_html(&$src)")
                        }
                        $i = $j + 1; $changed = $true; $total++
                        continue
                    }
                }
            }
            [void]$out.Add($line)
            $i++
        }
        if ($changed) { [System.IO.File]::WriteAllLines($f.FullName, $out, $enc) }
    }
}
Write-Output "fifth-pass blocks converted: $total"
