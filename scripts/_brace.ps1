# Brace balance that ignores comments and string literals.
param([Parameter(Mandatory=$true)][string]$Path, [int]$From = 1, [int]$To = 0)
$lines = [System.IO.File]::ReadAllLines($Path)
if ($To -le 0) { $To = $lines.Count }
$depth = 0
for ($i = $From - 1; $i -lt $To; $i++) {
    $line = $lines[$i]
    # drop `//` comments (not inside strings: good enough for this file)
    $code = $line
    $inStr = $false
    $out = New-Object System.Text.StringBuilder
    for ($c = 0; $c -lt $code.Length; $c++) {
        $ch = $code[$c]
        if ($inStr) {
            if ($ch -eq '\') { $c++; continue }
            if ($ch -eq '"') { $inStr = $false }
            continue
        }
        if ($ch -eq '"') { $inStr = $true; continue }
        if ($ch -eq '/' -and $c + 1 -lt $code.Length -and $code[$c + 1] -eq '/') { break }
        [void]$out.Append($ch)
    }
    $clean = $out.ToString()
    $depth += ([regex]::Matches($clean, '\{')).Count - ([regex]::Matches($clean, '\}')).Count
    if ($depth -lt 1 -and $i -lt ($To - 1)) {
        Write-Output ("depth $depth at line " + ($i + 1) + ": " + $line)
        break
    }
}
Write-Output ("final depth: $depth")
