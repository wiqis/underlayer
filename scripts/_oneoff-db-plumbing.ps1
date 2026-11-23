# Uniform `*DbClient` for web handlers, and the app's route bodies pass
# `&courses_dir` now that the local is a value.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

Get-ChildItem $root -Filter *.ch | ForEach-Object {
    $t = [System.IO.File]::ReadAllText($_.FullName).Replace("`r`n", "`n")
    $n = $t.Replace('db : &DbClient', 'db : *DbClient')
    $n = $n.Replace('get_learner_id_from_token(db : *DbClient, req : &http::Request)', 'get_learner_id_from_token(db : *DbClient, req : &http::Request)')
    $n = [regex]::Replace($n, '\(&raw db,', '(db,')
    $n = [regex]::Replace($n, '\(&db,', '(db,')
    $n = [regex]::Replace($n, '\(&raw db\)', '(db)')
    $n = [regex]::Replace($n, '\(&db\)', '(db)')
    $n = [regex]::Replace($n, ',\s*&raw db,', ', db,')
    $n = [regex]::Replace($n, ',\s*&db,', ', db,')
    if ($n -ne $t) { [System.IO.File]::WriteAllText($_.FullName, $n, $enc) }
}
Write-Output 'web handlers take *DbClient'

# The app: the process-wide DB is a pointer to the live client, and route bodies
# pass the courses directory by reference.
$p = 'D:\Programming\Wiqis\Web\underlayer\app\main.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
@never_destructed
var g_db : underlayer_db::DbClient
@never_destructed
var g_courses_dir : string

// Fill the two values once, before the server starts accepting.
func set_process_state(dbv : &underlayer_db::DbClient, courses : &string) {
    unsafe {
        g_db = *dbv
        g_courses_dir = std::replace(&mut g_courses_dir, courses.copy())
    }
}

// The process's database handle.  Valid for the life of the process.
public func request_db() : *underlayer_db::DbClient {
    return unsafe(&raw mut g_db)
}
'@.Replace("`r`n","`n"),
@'
// A pointer to the `DbClient` main() owns, and a copy of the courses directory.
// Storing the address is deliberate: copying a `DbClient` would copy the
// `http::Client`'s mutex and hand out a second view of one connection.
@never_destructed
var g_db : *underlayer_db::DbClient
@never_destructed
var g_courses_dir : string

// Fill the two values once, before the server starts accepting.
func set_process_state(dbv : *underlayer_db::DbClient, courses : &string) {
    unsafe {
        g_db = dbv
        g_courses_dir = std::replace(&mut g_courses_dir, courses.copy())
    }
}

// The process's database handle.  Valid for the life of the process.
public func request_db() : *underlayer_db::DbClient {
    return unsafe(g_db)
}
'@.Replace("`r`n","`n"))

# Call it right after the DB is opened.
$t = $t.Replace(
'    var db = underlayer_db::make_client(db_url.copy(), db_token.copy())',
@'
    var db = underlayer_db::make_client(db_url.copy(), db_token.copy())
    var courses_dir_value = cfg.courses_dir.copy()
    set_process_state(&raw db, &courses_dir_value)
'@.Replace("`r`n","`n"))

# Route bodies: courses_dir local is a value, so handlers get a reference.
$t = [regex]::Replace($t, '\(courses_dir,', '(&courses_dir,')
$t = [regex]::Replace($t, ', courses_dir,', ', &courses_dir,')
$t = [regex]::Replace($t, ', courses_dir\)', ', &courses_dir)')
$t = [regex]::Replace($t, '\(courses_dir\)', '(&courses_dir)')
[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'app state + courses references'
