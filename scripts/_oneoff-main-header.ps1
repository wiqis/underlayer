# Rewrite the process-wide state header of app/main.ch cleanly (the previous pass
# left a duplicate g_db declaration and stale comment lines).
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$lines = [System.IO.File]::ReadAllLines($p)
$head = @'
// Underlayer — Server entrypoint
// Phase 1: Minimal working platform serving static courses.
using std::string
using std::string_view

// ---- Process-wide state ------------------------------------------------
//
// The router stores handlers as `Send + Sync + 'static`, so a handler cannot
// capture the `DbClient` — and a `DbClient` holds the live SQLite handle, which
// is not `Send`. There is one per process, so it lives here and is reached
// through the accessor below. That single `unsafe` read is the whole of the
// process-wide database state; every route stays safe and captures nothing.
//
// It is a POINTER, not a copy: copying a `DbClient` would copy the
// `http::Client`'s mutex and hand out a second view of one connection, which is
// exactly the by-value-capture bug recorded at the /api/exercises/submit route.
//
// The courses directory is process state too, but the web layer is who reads it,
// so it lives there: `underlayer_web::set_courses_dir` / `request_courses_dir`.
@never_destructed
var g_db : *underlayer_db::DbClient

// Fill the value once, before the server starts accepting.
func set_process_state(dbv : *underlayer_db::DbClient, courses : &string) {
    unsafe {
        g_db = dbv
    }
    underlayer_web::set_courses_dir(courses)
}

// The process's database handle.  Valid for the life of the process.
public func request_db() : *underlayer_db::DbClient {
    return unsafe(g_db)
}

'@ -split "`r?`n"

# Everything from `public func main()` on is kept.
$start = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^public func main\(\) : int \{') { $start = $i; break }
}
if ($start -lt 0) { throw 'main() not found' }
$rest = $lines[$start..($lines.Count - 1)]
# Trim a trailing empty string the split may have produced.
$headClean = @()
foreach ($h in $head) { if ($h -ne '' -or $headClean.Count -gt 0) { $headClean += $h } }
while ($headClean.Count -gt 0 -and $headClean[$headClean.Count - 1] -eq '') { $headClean = $headClean[0..($headClean.Count - 2)] }
$out = $headClean + @('') + $rest

[System.IO.File]::WriteAllLines($p, $out, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'main.ch header rewritten'
