param([Parameter(Mandatory=$true)][string]$Log, [int]$Limit = 60)
# Print error locations from a compiler log, with the offending source line.
$lines = Get-Content -LiteralPath $Log
$root = 'D:\Programming\Wiqis\Web\underlayer\'
$seen = @{}
$out = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -match 'error') {
        $loc = $lines[$i + 1]
        if ($loc -match '([A-Za-z]:\\[^:]+\.ch):(\d+)') {
            $file = $matches[1]; $ln = [int]$matches[2]
            $key = "$file|$ln"
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $short = $file.Replace($root, '')
                $src = ''
                try { $src = (Get-Content -LiteralPath $file -TotalCount $ln)[$ln - 1] } catch { $src = '<?>' }
                $msg = ($l -replace '^TCCCompiler\.exe : ', '') -replace ' at $', ''
                if ($msg.Length -gt 95) { $msg = $msg.Substring(0, 95) }
                [void]$out.Add(("{0}:{1}  {2}`n      {3}" -f $short, $ln, $msg, $src.Trim()))
            }
        }
    }
}
$out | Select-Object -First $Limit
Write-Output ("TOTAL UNIQUE SITES: " + $out.Count)
