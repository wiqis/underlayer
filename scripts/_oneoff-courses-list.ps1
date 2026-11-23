# Replace lines 512..548 of repository/src/courses.ch (the read_dir callback
# block) with the value-based fs::read_dir scan.
$path = 'D:\Programming\Wiqis\Web\underlayer\repository\src\courses.ch'
$lines = [System.IO.File]::ReadAllLines($path)
# find the start marker
$start = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '// Scan the courses directory for subdirectories') { $start = $i; break }
}
if ($start -lt 0) { throw 'start marker not found' }
# find the closing "return courses" after it
$end = -1
for ($i = $start; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*return courses\s*$') { $end = $i; break }
}
if ($end -lt 0) { throw 'end marker not found' }
$replacement = @'
        // Scan the courses directory for subdirectories containing a manifest.json.
        // This makes the platform multi-course: any new course dir is picked up
        // automatically at startup without code changes.  `fs::read_dir` returns
        // the entries as values now, so there is no callback to capture into and
        // no `*char` name to walk.
        var dir_view = std::str.make_view(courses_dir.to_view())
        var dir_path = path::Path.new(dir_view)
        var scan_res = fs::read_dir(&dir_path)
        if(scan_res is std::Result.Ok) {
            var Ok(entries) = scan_res else unsafe { unreachable }
            var ei : size_t = 0
            while(ei < entries.size()) {
                var entry = entries.at_ref(ei)
                if(entry.is_dir()) {
                    var cid = entry.file_name()
                    var course = load_course(courses_dir, &cid)
                    if(course.id.size() > 0) {
                        courses.push(course)
                    }
                }
                ei = ei + 1
            }
            if(courses.size() > 0) { return courses }
        }
        {
            // Directory missing or unreadable -- fall back to the known course.
            var known = vector<string>()
            known.push(string("elf"))
            var i : size_t = 0
            while(i < known.size()) {
                var cid_val = known.at_ref(i).copy()
                var course = load_course(courses_dir, &cid_val)
                if(course.id.size() > 0) {
                    courses.push(course)
                }
                i = i + 1
            }
        }
        return courses
'@ -split "`r?`n"
$out = @()
if ($start -gt 0) { $out += $lines[0..($start - 1)] }
$out += $replacement
if ($end + 1 -lt $lines.Count) { $out += $lines[($end + 1)..($lines.Count - 1)] }
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $out, $enc)
Write-Output "replaced lines $($start+1)..$($end+1)"
