# Third pass: "status + body + write" with no content-type line at all.
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
            if ($m.Success -and ($i + 3 -lt $lines.Count) -and ($lines[$i + 1] -match 'var body = std::string\(') -and ($lines[$i + 2] -match 'var bv = body\.to_view\(\)') -and ($lines[$i + 3] -match 'res\.write_view\(&bv\)')) {
                $indent = $m.Groups[1].Value
                $status = $m.Groups[2].Value
                [void]$out.Add($lines[$i + 1])
                [void]$out.Add("${indent}return underlayer_web::send_status_text(${status}u, &body)")
                $i += 4; $changed = $true; $total++
                continue
            }
            [void]$out.Add($line)
            $i++
        }
        if ($changed) { [System.IO.File]::WriteAllLines($f.FullName, $out, $enc) }
    }
}
Write-Output "third-pass blocks converted: $total"
