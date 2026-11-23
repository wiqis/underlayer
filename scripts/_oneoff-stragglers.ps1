# Sixth pass: hand-shaped stragglers (export download, lesson pages).
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# --- handlers_data.ch: JSON export with Content-Disposition ---
$p = Join-Path $root 'handlers_data.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
        res.set_header_view(std::string_view("Content-Disposition"), &std::string_view("attachment; filename=\"underlayer_export.json\""))
        var bv = body.to_view()
        res.write_view(&bv)
'@.Replace("`r`n","`n"),
@'
        var res = send_json_str(&body)
        var disposition = std::string_view("attachment; filename=\"underlayer_export.json\"")
        res.set_header_view(std::string_view("Content-Disposition"), &disposition)
        return res
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- handlers_lessons.ch: two write paths, both HTML ---
$p = Join-Path $root 'handlers_lessons.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        apply_security_headers(res)
'@.Replace("`r`n","`n"), '')
$t = $t.Replace(
@'
                var pv2 = full.to_view()
                res.write_view(&pv2)
                return
'@.Replace("`r`n","`n"),
@'
                return send_html(&full)
'@.Replace("`r`n","`n"))
$t = $t.Replace(
@'
        var pv = headed.to_view()
        res.write_view(&pv)
    }
'@.Replace("`r`n","`n"),
@'
        return send_html(&headed)
    }
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- static.ch: serve a file's bytes ---
$p = Join-Path $root 'static.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
        var ct_view = ct.to_view()
        res.set_header_view(std::string_view("Content-Type"), &ct_view)
        apply_security_headers(res)

        var body_view = std::string_view(bytes.data() as *char, bytes.size())
        res.write_view(&body_view)
    }
'@.Replace("`r`n","`n"),
@'
        var res = http::Response()
        var ct_view = ct.to_view()
        res.set_header_view(std::string_view("Content-Type"), &ct_view)
        apply_security_headers(&mut res)
        res.bytes(bytes.as_span())
        return res
    }
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)
Write-Output 'stragglers 1-3 rewritten'
