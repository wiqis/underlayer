# Fix the remaining web/src compile errors: Option-typed query values, render
# helpers that still take model pointers, and the last raw fs/response calls.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# Add sv_or_empty next to the other helpers.
$p = Join-Path $root 'helpers.ch'
$t = [System.IO.File]::ReadAllText($p)
if (-not $t.Contains('func sv_or_empty')) {
    $t = $t.Replace(
'    public func sv_to_string(sv : *string_view) : string {',
@'
    // A decoded value-or-empty form of `QueryMap.get`, which returns an Option.
    // Every call site that wants "the value, or nothing" reads through this.
    public func sv_or_empty(value : std::Option<std::string_view>) : std::string_view {
        if(value is std::Option.None) { return std::string_view("") }
        var Some(v) = value else unsafe { unreachable }
        return v
    }

    public func sv_to_string(sv : *string_view) : string {
'@.Replace("`r`n", "`n"))
    [System.IO.File]::WriteAllText($p, $t, $enc)
}

# Wrap the query reads that treat the result as a value.
$sites = @{
    'handlers_progress_overview.ch' = @('var v = req.query.get(&q.to_view())')
    'handlers_search_concepts.ch'   = @()
    'handlers_weakness.ch'          = @()
    'handlers_knowledge_health.ch'  = @('var val = req.query.get(&key_sv)')
    'handlers_settings.ch'          = @('var weights_v = req.query.get(&q_weights.to_view())')
    'handlers_notes.ch'             = @('var qv = req.query.get(&q_key.to_view())')
}
foreach ($name in $sites.Keys) {
    $p = Join-Path $root $name
    $t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
    # Generic: `var X = req.query.get(EXPR)` -> `var X = sv_or_empty(req.query.get(EXPR))`
    $t = [regex]::Replace($t, 'var (\w+) = req\.query\.get\(([^)]*)\)', 'var $1 = sv_or_empty(req.query.get($2))')
    [System.IO.File]::WriteAllText($p, $t, $enc)
}

# Render helpers take model references, not pointers.
foreach ($name in @('courses_index_render.ch', 'courses_path_render.ch')) {
    $p = Join-Path $root $name
    $t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
    $t = $t -replace '(card|rc|dep|u|step|route) : \*(CourseCard|RouteCard|StepCard|CourseRoute|RouteStep|Course)\b', '$1 : &$2'
    $t = $t -replace ': \*vector<(CourseCard|Course|CourseRoute)>', ': &vector<$1>'
    [System.IO.File]::WriteAllText($p, $t, $enc)
}

# static.ch: read the file with the safe fs API.
$p = Join-Path $root 'static.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
        var content_res = fs::read_entire_file(fs_path.data())
        if(content_res is std::Result.Err) {
            var err_msg = std::string("file not found")
            return send_error(404u, &err_msg)
            return
        }
        var Ok(bytes) = content_res else unsafe { unreachable }
'@.Replace("`r`n","`n"),
@'
        var path_view = std::str.make_view(fs_path.to_view())
        var file_path = path::Path.new(path_view)
        var content_res = fs::read(&file_path)
        if(content_res is std::Result.Err) {
            var err_msg = std::string("file not found")
            return send_error(404u, &err_msg)
        }
        var Ok(bytes) = content_res else unsafe { unreachable }
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'web/src stragglers pass 1'
