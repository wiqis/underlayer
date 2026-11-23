# Final web/src fixes: read_body via the framework's buffered body, the remaining
# Option-typed JSON node uses, session guard call sites, and one more model pointer.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# --- helpers.ch: read_body ---
$p = Join-Path $root 'helpers.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$start = $t.IndexOf('    public func read_body(')
$end = $t.IndexOf('    // HAT course concept ids.')
if ($start -lt 0 -or $end -lt 0) { throw 'read_body markers not found' }
$block = @'
    // The request body as text.
    //
    // The framework has already framed and buffered the body (bounded by
    // `ServerConfig.max_body_bytes`), so a handler reads it out of the request
    // rather than off the socket.  The old version streamed `req.body.read(...)`
    // into an 8 KiB stack buffer and had to special-case an empty body.
    public func read_body(req : &mut http::Request) : string {
        var text = req.body_text()
        var out = std::string()
        out.append_view(&text)
        return out
    }

'@
$t = $t.Substring(0, $start) + $block.Replace("`r`n", "`n") + $t.Substring($end)
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- handlers_data.ch: two imported arrays ---
$p = Join-Path $root 'handlers_data.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
        var states_val = json_get(&parsed, "concept_states")
        if(states_val is JsonValue.Array) {
            var Array(states_arr) = states_val else unsafe { unreachable }
'@.Replace("`r`n","`n"),
@'
        var states_opt = json_get(&parsed, "concept_states")
        if(states_opt is std::Option.Some) {
            var Some(states_val) = states_opt else unsafe { unreachable }
            var Array(states_arr) = states_val else unsafe { unreachable }
'@.Replace("`r`n","`n"))
$t = $t.Replace(
@'
        var reviews_val = json_get(&parsed, "course_reviews")
        if(reviews_val is JsonValue.Array) {
            var Array(reviews_arr) = reviews_val else unsafe { unreachable }
'@.Replace("`r`n","`n"),
@'
        var reviews_opt = json_get(&parsed, "course_reviews")
        if(reviews_opt is std::Option.Some) {
            var Some(reviews_val) = reviews_opt else unsafe { unreachable }
            var Array(reviews_arr) = reviews_val else unsafe { unreachable }
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- courses_path_render.ch: route param ---
$p = Join-Path $root 'courses_path_render.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t -replace 'route : \*PathRoute', 'route : &PathRoute'
$t = $t.Replace('render_route_step(&raw mut rc, page)', 'render_route_step(&mut rc, page)')
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- handlers_review.ch: session guard call sites ---
$p = Join-Path $root 'handlers_review.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
'        if(!require_own_session(&db, req, res, &session_id)) { return }',
@'
        var guard = require_own_session(&db, req, &session_id)
        if(guard is std::Option.Some) {
            var Some(refusal) = guard else unsafe { unreachable }
            return refusal
        }
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'web/src stragglers pass 3'
