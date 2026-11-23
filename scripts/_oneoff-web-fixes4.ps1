# Last-mile fixes 4.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# rate_limit: allow path returns None.
$p = Join-Path $root 'rate_limit.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
        underlayer_db::exec_sql(db, &raw upsert)
        return true
    }
'@.Replace("`r`n","`n"),
@'
        underlayer_db::exec_sql(db, &raw upsert)
        return std::Option.None<http::Response>()
    }
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)

# nav_search: the entry appender needs a mutable body.
$p = Join-Path $root 'handlers_nav_search.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace('func append_nav_entry(body : &string, label : string, course_id : string, concept_id : string) {',
                'func append_nav_entry(body : &mut string, label : string, course_id : string, concept_id : string) {')
$t = $t.Replace('append_nav_entry(body, ', 'append_nav_entry(&mut body, ')
[System.IO.File]::WriteAllText($p, $t, $enc)

# search_scan: sort by swapping through a mutable element borrow.
$p = Join-Path $root 'search_scan.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace('        var a = hits.at_ref(i)' + "`n" + '        var b = hits.at_ref(j)',
                '        var a = hits.at_mut(i)' + "`n" + '        var b_ref = hits.at_ref(j)')
$t = [regex]::Replace($t, '(\n\s+)a\.(\w+) = b\.', '$1a.$2 = b_ref.')
$t = [regex]::Replace($t, '(\n\s+)b\.(\w+) = s_', '$1b_ref.$2 = s_')
[System.IO.File]::WriteAllText($p, $t, $enc)

# knowledge_health: make_no_len is unsafe.
$p = Join-Path $root 'handlers_knowledge_health.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace('var key_str = string::make_no_len(key)', 'var key_str = unsafe(std::string::make_no_len(key))')
[System.IO.File]::WriteAllText($p, $t, $enc)

# handlers_progress: append_coverage_json takes &mut string now.
$p = Join-Path $root 'handlers_progress.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace('append_coverage_json(&raw mut body, &cov, &states, &health)', 'append_coverage_json(&mut body, &cov, &states, &health)')
[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'last-mile 4'
