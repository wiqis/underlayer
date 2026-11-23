# Route closures: no captures.  Process-wide DB/courses accessors, and each
# closure body gets local handles so the handler calls are unchanged.
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")

# 1. Capture lists -> none.
$t = [regex]::Replace($t, '\(\|[^|]*\|\(req\) => \{', '||(req) => {')

# 2. Split into route blocks and rewrite the bodies.
$lines = $t -split "`n"
$out = New-Object System.Collections.ArrayList
$inRoute = $false
$headerEmitted = $false
$depth = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if (-not $inRoute -and $line -match 'srv\.router\.add\(') {
        $inRoute = $true
        $headerEmitted = $false
        [void]$out.Add($line)
        continue
    }
    if ($inRoute) {
        # A route ends at a line that is exactly "    }))".
        if ($line -match '^\s*\}\)\)\s*$') {
            $inRoute = $false
            [void]$out.Add($line)
            continue
        }
        if (-not $headerEmitted -and $line -match '^\s*\}?\)?\)?\s*$') {
            [void]$out.Add($line)
            continue
        }
        $l = $line
        $l = $l.Replace('&raw dbp,', 'dbp,').Replace('&dbp,', 'dbp,').Replace('(&raw dbp)', '(dbp)').Replace('(&dbp)', '(dbp)')
        $l = $l.Replace('&raw db,', 'db,').Replace('&db,', 'db,').Replace('(&raw db)', '(db)').Replace('(&db)', '(db)')
        $l = $l.Replace('var dbp = db', 'var dbp = db')
        [void]$out.Add($l)
        continue
    }
    [void]$out.Add($line)
}
$t = ($out -join "`n")

# 3. Insert the two locals at the top of each closure body that uses them.
$lines = $t -split "`n"
$out2 = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    [void]$out2.Add($line)
    if ($line -match 'srv\.router\.add\(' -and $line -match '\|\|\(req\) => \{\s*$') {
        # Look ahead to the end of this block for identifier use.
        $end = $i + 1
        while ($end -lt $lines.Count -and -not ($lines[$end] -match '^\s*\}\)\)\s*$')) { $end++ }
        $body = ($lines[($i + 1)..([Math]::Max($i + 1, $end - 1))] -join "`n")
        $usesDb = $body -match '(?<![\w\.])db(?![\w])'
        $usesCourses = $body -match '(?<![\w\.])courses_dir(?![\w])'
        if ($usesCourses) { [void]$out2.Add('        var courses_dir = request_courses_dir()') }
        if ($usesDb) { [void]$out2.Add('        var db = request_db()') }
    }
}
$t = ($out2 -join "`n")

# 4. The process-wide state itself, right before main().
$state = @'
// ---- Process-wide state ------------------------------------------------
//
// The router stores handlers as `Send + Sync + 'static`, so a handler cannot
// capture the `DbClient` or the courses directory by reference -- and a
// `DbClient` holds the live SQLite handle, which is not `Send`.  There is one of
// each per process, so they live here and are reached through the two accessors
// below.  Those two `unsafe` blocks are the whole of the process-wide state
// handling in the application; every route stays safe and captures nothing.
//
// The value is a POINTER, not a copy: copying a `DbClient` would copy the
// `http::Client`'s mutex and hand out a second view of one connection, which is
// exactly the by-value-capture bug recorded at the /api/exercises/submit route.
@never_destructed var g_db : DbClient
@never_destructed var g_courses_dir : string

// Fill the two values once, before the server starts accepting.
func set_process_state(dbv : &DbClient, courses : &string) {
    unsafe {
        g_db = *dbv
        g_courses_dir = std::replace(&mut g_courses_dir, courses.copy())
    }
}

// The process's database handle.  Valid for the life of the process.
public func request_db() : *DbClient {
    return unsafe(&raw mut g_db)
}

// The courses directory, as a value: handlers take `&string` and must not hold a
// view into the global.
public func request_courses_dir() : string {
    return unsafe(g_courses_dir.copy())
}

'@
$t = $t.Replace('public func main() : int {', $state.Replace("`r`n", "`n") + 'public func main() : int {')

[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ('remaining capture lists: ' + (Select-String -Path $p -Pattern '\(\|&\?db' | Measure-Object).Count)
Write-Output ('request_db uses: ' + (Select-String -Path $p -Pattern 'request_db\(\)' | Measure-Object).Count)
