# Move the process-wide courses-directory buffer into the web layer, where the page
# handlers that need it live.
$enc = New-Object System.Text.UTF8Encoding($false)

# --- app/main.ch: drop the buffer, delegate the setter ---
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$start = $t.IndexOf('// The courses directory, as a fixed buffer rather than a `string` global')
if ($start -lt 0) { throw 'courses buffer block not found' }
$end = $t.IndexOf('public func main() : int {')
if ($end -lt 0) { throw 'main marker not found' }
$replacement = @'
// The database handle main() owns.  The courses directory is process state too,
// but it belongs to the web layer (that is who reads it), so it lives there —
// `underlayer_web::set_courses_dir` / `underlayer_web::request_courses_dir`.
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

'@.Replace("`r`n", "`n")
$t = $t.Substring(0, $start) + $replacement + $t.Substring($end)
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- web/src/responses.ch: own the buffer ---
$p = 'D:\Programming\Wiqis\Web\underlayer\web\src\responses.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$anchor = '    // The 404 page, as the App'
if (-not $t.Contains($anchor)) { throw 'responses anchor not found' }
$block = @'
    // ---- Process-wide: the course content directory ----
    //
    // Every page route needs to know where `courses/` is, and a route handler
    // cannot capture it (the router stores handlers as `Send + Sync + 'static`).
    // It is one value for the process, set once from `main` and read by the page
    // handlers, so it lives here.
    //
    // It is a fixed char buffer and not a `string`: a zero-initialised
    // `@never_destructed` global is not a constructed value, and a `string` global
    // assigned at boot read back EMPTY at request time (measured: every manifest
    // path came out as "/<course>/manifest.json").
    comptime const COURSES_DIR_MAX : size_t = 512
    @never_destructed
    var g_courses_buf : [COURSES_DIR_MAX]char
    @never_destructed
    var g_courses_len : size_t

    public func set_courses_dir(courses : &string) {
        unsafe {
            var n = courses.size()
            if(n >= COURSES_DIR_MAX) { n = COURSES_DIR_MAX - 1 }
            var i : size_t = 0
            while(i < n) {
                g_courses_buf[i] = courses.at(i)
                i = i + 1
            }
            g_courses_buf[n] = 0
            g_courses_len = n
        }
    }

    // The courses directory, as a value: callers take `&string` and must not hold
    // a view into the global.
    public func request_courses_dir() : string {
        var out = std::string()
        var n = unsafe(g_courses_len)
        var i : size_t = 0
        while(i < n) {
            out.append(unsafe(g_courses_buf[i]))
            i = i + 1
        }
        return out
    }

        // The 404 page, as the App
'@.Replace("`r`n", "`n")
$t = $t.Replace($anchor, $block)
[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'courses dir moved into the web layer'



