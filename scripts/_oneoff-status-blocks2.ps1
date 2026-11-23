# Second pass: the variant where the Content-Type line sits after the body.
param([Parameter(Mandatory=$true)][string[]]$Paths)
$enc = New-Object System.Text.UTF8Encoding($false)
$total = 0
foreach ($p in $Paths) {
    $files = if (Test-Path -PathType Container $p) { Get-ChildItem -Path $p -Recurse -Filter *.ch -File } else { Get-Item $p }
    foreach ($f in $files) {
        $lines = [System.IO.File]::ReadAllLines($f.FullName)
        $out = New-Object System.Collections.ArrayList
        $i = 0; $changed = $false
        while ($i -lt $lines.Count) {
            $line = $lines[$i]
            $m = [regex]::Match($line, '^(\s*)res\.status = (\d+)u\s*$')
            if ($m.Success -and ($i + 4 -lt $lines.Count) -and ($lines[$i + 1] -match 'var body = std::string\(') -and ($lines[$i + 2] -match 'var bv = body\.to_view\(\)') -and ($lines[$i + 3] -match 'res\.set_header_view\(') -and ($lines[$i + 4] -match 'res\.write_view\(&bv\)')) {
                $indent = $m.Groups[1].Value
                $status = $m.Groups[2].Value
                $isJson = $lines[$i + 3] -match 'application/json'
                $helper = if ($isJson) { 'send_json_status' } else { 'send_status_text' }
                [void]$out.Add($lines[$i + 1])
                [void]$out.Add("${indent}return underlayer_web::${helper}(${status}u, &body)")
                $i += 5; $changed = $true; $total++
                continue
            }
            [void]$out.Add($line)
            $i++
        }
        if ($changed) { [System.IO.File]::WriteAllLines($f.FullName, $out, $enc) }
    }
}
Write-Output "second-pass blocks converted: $total"
