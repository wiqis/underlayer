# Type-level last mile: bare returns, query key type, read_body argument,
# append_html argument, query_sql pointer form, and model pointer params.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'
$total = 0

foreach ($f in Get-ChildItem -Path $root -Recurse -Filter *.ch -File) {
    $lines = [System.IO.File]::ReadAllLines($f.FullName)
    $out = New-Object System.Collections.ArrayList
    $changed = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # A bare `return` on the line after a `return <value>` is dead code from
        # the writer era; drop it.
        if ($line -match '^\s*return\s*$' -and $out.Count -gt 0 -and $out[$out.Count - 1] -match '^\s*return\s+\S') {
            $changed = $true
            continue
        }
        [void]$out.Add($line)
    }
    if ($changed) { [System.IO.File]::WriteAllLines($f.FullName, $out, $enc); $total++ }
}
Write-Output "bare-return cleanup in $total files"

# Argument shape fixes.
Get-ChildItem $root -Filter *.ch | ForEach-Object {
    $t = [System.IO.File]::ReadAllText($_.FullName).Replace("`r`n", "`n")
    $n = $t
    $n = $n.Replace('read_body(&raw mut req)', 'read_body(&mut req)')
    $n = $n.Replace('page.append_html(html_str)', 'page.append_html(&html_str)')
    # query keys: `&string_view` -> `&str`
    $n = [regex]::Replace($n, 'req\.query\.get\(&(\w+)\.to_view\(\)\)', 'req.query.get(std::str.make_view($1.to_view()))')
    $n = [regex]::Replace($n, 'req\.query\.get\(&(\w+_sv)\)', 'req.query.get(std::str.make_view($1))')
    # query_sql/exec_sql still take raw string pointers
    $n = [regex]::Replace($n, 'underlayer_db::query_sql\(([^,]+), &(\w+)\)', 'underlayer_db::query_sql($1, &raw $2)')
    $n = [regex]::Replace($n, 'underlayer_db::exec_sql\(([^,]+), &(\w+)\)', 'underlayer_db::exec_sql($1, &raw $2)')
    # model vector params in the progress-json renderer
    $n = $n -replace 'states : \*vector<ConceptState>', 'states : &vector<ConceptState>'
    if ($n -ne $t) { [System.IO.File]::WriteAllText($_.FullName, $n, $enc) }
}
Write-Output 'argument shapes fixed'
