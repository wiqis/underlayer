# Replace the copied "random bytes -> hex" and "sha256 -> hex" bodies in the web
# layer with the core helpers.
$enc = New-Object System.Text.UTF8Encoding($false)
$root = 'D:\Programming\Wiqis\Web\underlayer\web\src'

# --- handlers_auth.ch: both helpers delegate to core ---
$p = Join-Path $root 'handlers_auth.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
$start = $t.IndexOf('    public func generate_random_hex(')
$end = $t.IndexOf('    // Session and reset tokens are stored as SHA-256')
if ($start -lt 0 -or $end -lt 0) { throw "auth markers not found ($start, $end)" }
$block = @'
    // A lowercase hex string of `len` characters, from `len / 2` random bytes.
    //
    // Both this and `sha256_hex` are one line over `underlayer_core`, which owns
    // the randomness source and the digest.  They used to be two hand-written
    // 12-line bodies with their own fixed-size buffers, and the same body
    // appeared again in handlers_profiles, handlers_settings_api and
    // password_hash.
    public func generate_random_hex(len : size_t) : string {
        var full = underlayer_core::random_hex((len + 1) / 2)
        if(full.size() <= len) { return full }
        return full.substring(0, len)
    }

    // Lowercase hex SHA-256 of `text`.
    public func sha256_hex(text : &std::string_view) : string {
        return underlayer_core::sha256_hex(text)
    }

'@
$t = $t.Substring(0, $start) + $block.Replace("`r`n", "`n") + $t.Substring($end)
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- handlers_profiles.ch / handlers_settings_api.ch: token hash inline ---
foreach ($name in @('handlers_profiles.ch', 'handlers_settings_api.ch')) {
    $p = Join-Path $root $name
    $t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
    $t = $t.Replace(
@'
        var data = token.data() as *u8
        var digest : [32]u8
        var di : size_t = 0
        while(di < 32) { digest[di] = 0; di = di + 1 }
        crypto::sha256_hash(data, token.size(), &raw mut digest[0])
        var hex_out : [65]char
        var hi : size_t = 0
        while(hi < 65) { hex_out[hi] = 0; hi = hi + 1 }
        encoding::hex_encode(&raw digest[0], 32, &raw mut hex_out[0], 65)
        var token_hash = string()
        hi = 0
        while(hi < 64 && hex_out[hi] != 0) { token_hash.append(hex_out[hi]); hi = hi + 1 }
'@.Replace("`r`n","`n"),
@'
        var token_view = token.to_view()
        var token_hash = underlayer_core::sha256_hex(&token_view)
'@.Replace("`r`n","`n"))
    [System.IO.File]::WriteAllText($p, $t, $enc)
}

# --- password_hash.ch: the legacy unsalted comparison ---
$p = Join-Path $root 'password_hash.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")
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
                if(hex_out[i] != stored.get(i)) { return false }
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
Write-Output 'crypto call sites routed through core'
