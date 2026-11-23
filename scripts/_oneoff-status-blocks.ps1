# Convert the remaining hand-written "status + content-type + write" blocks into
# a single returned response.  Line-based so it does not depend on quoting.
param([Parameter(Mandatory=$true)][string[]]$Paths)

$enc = New-Object System.Text.UTF8Encoding($false)
$totalBlocks = 0

foreach ($p in $Paths) {
    $files = if (Test-Path -PathType Container $p) { Get-ChildItem -Path $p -Recurse -Filter *.ch -File } else { Get-Item $p }
    foreach ($f in $files) {
        $lines = [System.IO.File]::ReadAllLines($f.FullName)
        $out = New-Object System.Collections.ArrayList
        $i = 0
        $changed = $false
        while ($i -lt $lines.Count) {
            $line = $lines[$i]
            $m = [regex]::Match($line, '^(\s*)res\.status = (\d+)u\s*$')
            if ($m.Success -and ($i + 5 -lt $lines.Count) -and ($lines[$i + 1] -match 'var ct = std::string_view\(') -and ($lines[$i + 2] -match 'res\.set_header_view\(') -and ($lines[$i + 3] -match 'var body = std::string\(') -and ($lines[$i + 4] -match 'var bv = body\.to_view\(\)') -and ($lines[$i + 5] -match 'res\.write_view\(&bv\)')) {
                $indent = $m.Groups[1].Value
                $status = $m.Groups[2].Value
                $bodyLine = $lines[$i + 3]
                $isJson = $lines[$i + 1] -match 'application/json'
                $helper = if ($isJson) { 'send_json_status' } else { 'send_status_text' }
                [void]$out.Add($bodyLine)
                [void]$out.Add("${indent}return underlayer_web::${helper}(${status}u, &body)")
                $i += 6
                $changed = $true
                $totalBlocks++
                continue
            }
            [void]$out.Add($line)
            $i++
        }
        if ($changed) {
            [System.IO.File]::WriteAllLines($f.FullName, $out, $enc)
        }
    }
}
Write-Output "blocks converted: $totalBlocks"

