# Remaining web/src fixes: constant-time compare, legacy sha256 block, page HTML
# append, and the two guard call sites.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# --- password_hash.ch ---
$p = Join-Path $root 'password_hash.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace(
@'
            var a = computed.data() as *u8
            var b = stored.data() as *u8
            return crypto::constant_time_equal(a, b, BCRYPT_HASH_LEN)
'@.Replace("`r`n","`n"),
@'
            var a : &[u8] = computed.as_bytes()
            var b : &[u8] = stored.as_bytes()
            return crypto::constant_time_equal(a, b)
'@.Replace("`r`n","`n"))
$t = $t.Replace(
@'
            var digest : [32]u8
            var di : size_t = 0
            while(di < 32u) { digest[di] = 0; di = di + 1 }
            crypto::sha256_hash(password.data() as *u8, password.size(), &raw mut digest[0])
            var hex_out : [65]char
            var hi : size_t = 0
            while(hi < 65u) { hex_out[hi] = 0; hi = hi + 1 }
            encoding::hex_encode(&raw digest[0], 32u, &raw mut hex_out[0], 65u)
            var i : size_t = 0
            while(i < 64u) {
                if(hex_out[i] != stored.at(i)) { return false }
                i = i + 1
            }
            return true
'@.Replace("`r`n","`n"),
@'
            var password_view = password.to_view()
            var computed_hex = underlayer_core::sha256_hex(&password_view)
            var i : size_t = 0
            while(i < 64u) {
                if(computed_hex.at(i) != stored.at(i)) { return false }
                i = i + 1
            }
            return true
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- handlers_certificates.ch ---
$p = Join-Path $root 'handlers_certificates.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace('        page.append_html(html.data(), html.size())',
                '        var html_str = std::str.make_view(html.to_view())' + "`n" + '        page.append_html(html_str)')
$t = $t.Replace(
'        if(!require_course_complete(db, courses_dir, &learner_id, &course_id, res)) { return }',
@'
        var gate = require_course_complete(db, courses_dir, &learner_id, &course_id)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return refusal
        }
'@.Replace("`r`n","`n"))
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- handlers_learning.ch: record_concept_read now returns the response ---
$p = Join-Path $root 'handlers_learning.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$t = $t.Replace('        record_concept_read(&db, &learner_id, &course_id, &concept_id, res)',
                '        return record_concept_read(&db, &learner_id, &course_id, &concept_id)')
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- query.get Option wrap everywhere it is still treated as a view ---
Get-ChildItem $root -Filter *.ch | ForEach-Object {
    $t = [System.IO.File]::ReadAllText($_.FullName).Replace("`r`n", "`n")
    $n = [regex]::Replace($t, 'var (\w+) = req\.query\.get\(([^)]*)\)', 'var $1 = sv_or_empty(req.query.get($2))')
    if ($n -ne $t) { [System.IO.File]::WriteAllText($_.FullName, $n, $enc); Write-Output ("query wrap: " + $_.Name) }
}
Write-Output 'web/src stragglers pass 2'
