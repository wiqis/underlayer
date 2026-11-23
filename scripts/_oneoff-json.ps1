// Replace the JSON helper block in repository/src/helpers.ch.
// The block runs from "// ---- JSON helpers ----" up to (but not including)
// "// A 32-hex-character random identifier".
$path = 'D:\Programming\Wiqis\Web\underlayer\repository\src\helpers.ch'
$t = [System.IO.File]::ReadAllText($path)
$startMarker = '    // ---- JSON helpers ----'
$endMarker = '    // A 32-hex-character random identifier'
$start = $t.IndexOf($startMarker)
$end = $t.IndexOf($endMarker)
if ($start -lt 0 -or $end -lt 0) { throw 'markers not found' }

$block = @'
    // ---- JSON helpers ----
    //
    // A manifest node is looked up by reference: `json_get` returns
    // `Option<&JsonValue>` borrowed from the document the caller owns, and the
    // callers `switch` on that reference.  This replaces a `*JsonValue` API that
    // (a) could not be dereferenced without `unsafe` and (b) returned a pointer
    // into a *copy* of the object it looked in, so the pointer outlived the map
    // it pointed at.  No pointer is returned and no node is copied.

    // The child of `obj` named `key`, or `None` when absent or when `obj` is not
    // an object.
    public func json_get(obj : &JsonValue, key : *char) : std::Option<&JsonValue> {
        // `key` is a C string literal; turning it into a `string` is the one
        // boundary in this block.
        var k = unsafe(std::string::make_no_len(key))
        switch(obj) {
            Object(values) => {
                return values.get(&k)
            }
            default => {
                return std::Option.None<&JsonValue>()
            }
        }
    }

    // The text of a String node, or "" for anything else.
    public func json_str(val : &JsonValue) : string {
        switch(val) {
            String(s) => { return s.copy() }
            default => { return string() }
        }
    }

    // The integer value of a Number node, or 0 for anything else.
    public func json_i64(val : &JsonValue) : i64 {
        switch(val) {
            Number(n) => { return parse_i64(n.to_view()) }
            default => { return 0 }
        }
    }

    public func json_int(val : &JsonValue) : int {
        return json_i64(val) as int
    }

    public func json_get_str(obj : &JsonValue, key : *char) : string {
        var found = json_get(obj, key)
        if(found is std::Option.Some) {
            var Some(node) = found else unsafe { unreachable }
            return json_str(node)
        }
        return string()
    }

    public func json_get_int(obj : &JsonValue, key : *char) : int {
        var found = json_get(obj, key)
        if(found is std::Option.Some) {
            var Some(node) = found else unsafe { unreachable }
            return json_int(node)
        }
        return 0
    }

    public func json_get_bool(obj : &JsonValue, key : *char) : bool {
        var found = json_get(obj, key)
        if(found is std::Option.None) { return false }
        var Some(node) = found else unsafe { unreachable }
        switch(node) {
            Bool(b) => { return b }
            String(s) => { return s.to_view().equals(string_view("true")) }
            Number(n) => { return parse_i64(n.to_view()) != 0 }
            default => { return false }
        }
    }

'@

$new = $t.Substring(0, $start) + $block.Replace("`r`n", "`n") + $t.Substring($end)
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $new, $enc)
Write-Output 'json block replaced'
