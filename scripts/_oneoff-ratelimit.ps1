# Rewrite the rate-limit gates so each one returns Option<http::Response>
# (None = allowed, Some = the refusal to send).
$p = 'D:\Programming\Wiqis\Web\underlayer\web\src\rate_limit.ch'
$t = [System.IO.File]::ReadAllText($p).Replace("`r`n", "`n")

# 1. The shared body: returns Option<http::Response>.
$t = $t.Replace(
'    public func rate_limit_ok_with(db : *DbClient, req : &http::Request, group : &string, res : *mut http::ResponseWriter, max : i64) : bool {',
'    public func rate_limit_ok_with(db : *DbClient, req : &http::Request, group : &string, max : i64) : std::Option<http::Response> {')

$t = $t.Replace(
@'
        if(count >= max) {
            var retry = window - (now % window)
            var retry_s = underlayer_core::int_to_string(retry)
            // The header NAME goes to set_header_view; putting it in the value
            // as well produced "Retry-After: Retry-After: 229" on the wire.
            var hdr_v = retry_s.to_view()
            res.set_header_view(string_view("Retry-After"), &hdr_v)
            res.status = 429u
            var msg = string("{\"error\":\"too many attempts; try again in ")
            msg.append_string(&retry_s)
            msg.append_view(" seconds\"}")
            return send_json_str(&msg)
            return false
        }
'@.Replace("`r`n", "`n"),
@'
        if(count >= max) {
            var retry = window - (now % window)
            var retry_s = underlayer_core::int_to_string(retry)
            var msg = string("{\"error\":\"too many attempts; try again in ")
            msg.append_string(&retry_s)
            msg.append_view(" seconds\"}")
            var refusal = send_json_str(&msg)
            // The header NAME goes to set_header_view; putting it in the value
            // as well produced "Retry-After: Retry-After: 229" on the wire.
            var hdr_v = retry_s.to_view()
            refusal.set_header_view(string_view("Retry-After"), &hdr_v)
            refusal.status = 429u
            return std::Option.Some<http::Response>(refusal)
        }
'@.Replace("`r`n", "`n"))

# 2. The per-endpoint wrappers.
$t = [regex]::Replace($t, 'public func (rate_limit_\w+)\(db : \*DbClient, req : &http::Request\) : http::Response : bool \{',
                            'public func $1(db : *DbClient, req : &http::Request) : std::Option<http::Response> {')
$t = [regex]::Replace($t, 'return rate_limit_ok_with\(db, req, &g, res, (rate_limit_\w+\(\))\)',
                            'return rate_limit_ok_with(db, req, &g, $1)')

# 3. Trailing `return false` of the allow path.
$t = $t.Replace('        return false
    }', '        return std::Option.None<http::Response>()
    }')

[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'rate_limit gates now return Option<http::Response>'
