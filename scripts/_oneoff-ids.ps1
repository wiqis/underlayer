param([Parameter(Mandatory=$true)][string[]]$Paths)
# Replace the copied "16 random bytes -> 32 hex chars" id bodies with a call to
# underlayer_repository::random_hex_id().  Matches the body only, never the
# surrounding function, so each generate_*_id keeps its own name.
$body = @'
        var buf : [16]u8
        osrand::random_fill(&raw mut buf[0], 16)
        var hex_out : [33]char
        var i0 : size_t = 0
        while(i0 < 33) { hex_out[i0] = 0; i0 = i0 + 1 }
        encoding::hex_encode(&raw buf[0], 16, &raw mut hex_out[0], 33)
        var result = string()
        var i : size_t = 0
        while(i < 32 && hex_out[i] != 0) { result.append(hex_out[i]); i = i + 1 }
        return result
'@
$repl = "        return random_hex_id()"
$enc = New-Object System.Text.UTF8Encoding($false)
$changed = 0
foreach($p in $Paths) {
    foreach($f in Get-ChildItem -Path $p -Recurse -Filter *.ch -File) {
        $t = [System.IO.File]::ReadAllText($f.FullName)
        $n = $t.Replace($body.Replace("`r`n", "`n"), $repl).Replace($body, $repl)
        if ($n -ne $t) { [System.IO.File]::WriteAllText($f.FullName, $n, $enc); $changed++ }
    }
}
Write-Output "id bodies replaced in $changed files"
