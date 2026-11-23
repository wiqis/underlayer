# Fix the guard helpers: they now return Option<http::Response> (None = allowed).
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# --- session_guard.ch ---
$p = Join-Path $root 'session_guard.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
'    public func require_own_session(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter, session_id : *string) : bool {',
'    public func require_own_session(db : *DbClient, req : &http::Request, session_id : &string) : std::Option<http::Response> {')
$t = $t.Replace(
@'
        var sid = session_id.copy()
        if(underlayer_repository::session_belongs_to(db, &sid, &learner_id)) {
            return true
        }
        var err = string("this session belongs to another learner")
        return send_error(403u, &err)
        return false
'@.Replace("`r`n","`n"),
@'
        var sid = session_id.copy()
        if(underlayer_repository::session_belongs_to(db, &sid, &learner_id)) {
            return std::Option.None<http::Response>()
        }
        var err = string("this session belongs to another learner")
        return std::Option.Some<http::Response>(send_error(403u, &err))
'@.Replace("`r`n","`n"))
$t = $t.Replace('    // Returns true when the caller may act on `session_id`.  On false the
    // response has already been written.', '    // `None` when the caller may act on `session_id`; `Some(response)` when it
    // may not, and that response is the 403 to send.')
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- completion_gate.ch ---
$p = Join-Path $root 'completion_gate.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
        course_id : &string,
        res : *mut http::ResponseWriter
    ) : bool {
'@.Replace("`r`n","`n"),
@'
        course_id : &string
    ) : std::Option<http::Response> {
'@.Replace("`r`n","`n"))
$t = $t.Replace('if(cov.concepts_total > 0 && cov.progress_percentage >= 100) { return true }',
                'if(cov.concepts_total > 0 && cov.progress_percentage >= 100) { return std::Option.None<http::Response>() }')
$t = $t.Replace(
@'
        res.status = 403u
        return send_json_str(&reason)
        return false
'@.Replace("`r`n","`n"),
@'
        var refusal = send_json_str(&reason)
        refusal.status = 403u
        return std::Option.Some<http::Response>(refusal)
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- handlers_learning.ch: record_concept_read returns the response ---
$p = Join-Path $root 'handlers_learning.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
        concept_id : &string,
        res : *mut http::ResponseWriter
    ) {
'@.Replace("`r`n","`n"),
@'
        concept_id : &string
    ) : http::Response {
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)

Write-Output 'guards converted'
