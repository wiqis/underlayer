// underlayer_repository — Shared helpers (public for cross-file use).
using std::string
using std::string_view

public namespace underlayer_repository {

    public func parse_i64(v : std::string_view) : i64 {
        var result : i64 = 0
        var negative = false
        var i : size_t = 0
        if(v.size() > 0 && v.get(0) == '-') { negative = true; i = 1 }
        while(i < v.size()) {
            var c = v.get(i)
            if(c >= '0' && c <= '9') { result = result * 10 + (c as i64 - 48) }
            i = i + 1
        }
        if(negative) { result = -result }
        return result
    }

    public func parse_int(v : std::string_view) : int {
        return parse_i64(v) as int
    }

    // Parse a float from string (e.g. "0.4072" -> 0.4072)
    public func parse_f64(v : std::string_view) : f64 {
        var result : f64 = 0.0
        var negative = false
        var i : size_t = 0
        if(v.size() > 0 && v.get(0) == '-') { negative = true; i = 1 }
        // Integer part
        while(i < v.size()) {
            var c = v.get(i)
            if(c >= '0' && c <= '9') { result = result * 10.0 + ((c as i64 - 48) as f64) }
            else if(c == '.') { i = i + 1; break }
            i = i + 1
        }
        // Fractional part
        var frac_mult : f64 = 0.1
        while(i < v.size()) {
            var c = v.get(i)
            if(c >= '0' && c <= '9') {
                result = result + ((c as i64 - 48) as f64) * frac_mult
                frac_mult = frac_mult * 0.1
            }
            i = i + 1
        }
        if(negative) { result = -result }
        return result
    }

    public func json_str(val : *JsonValue) : string {
        if(val == null) { return string() }
        if(val is JsonValue.String) {
            var String(s) = *val else unreachable
            return s.copy()
        }
        return string()
    }

    public func json_i64(val : *JsonValue) : i64 {
        if(val == null) { return 0 }
        if(val is JsonValue.Number) {
            var Number(s) = *val else unreachable
            return parse_i64(s.to_view())
        }
        return 0
    }

    public func json_int(val : *JsonValue) : int {
        return json_i64(val) as int
    }

    public func json_get(obj : *JsonValue, key : *char) : *mut JsonValue {
        if(obj == null) { return null }
        if(!(obj is JsonValue.Object)) { return null }
        var Object(map) = *obj else unreachable
        var k = string::make_no_len(key)
        return map.get_ptr(&k)
    }

    public func json_get_str(obj : *JsonValue, key : *char) : string {
        var field = json_get(obj, key)
        return json_str(field)
    }

    public func json_get_int(obj : *JsonValue, key : *char) : int {
        var field = json_get(obj, key)
        return json_int(field)
    }

    public func json_get_bool(obj : *JsonValue, key : *char) : bool {
        var field = json_get(obj, key)
        if(field == null) { return false }
        if(field is JsonValue.Bool) {
            var Bool(b) = *field else unreachable
            return b
        }
        if(field is JsonValue.String) {
            var String(s) = *field else unreachable
            if(s.to_view().equals(string_view("true"))) { return true }
        }
        if(field is JsonValue.Number) {
            var Number(n) = *field else unreachable
            if(parse_i64(n.to_view()) != 0) { return true }
        }
        return false
    }

    // Escape a string for embedding inside a single-quoted SQL literal:
    // ' becomes '' (standard SQL escaping). The codebase builds SQL by string
    // concatenation, so any user/manifest-supplied text must pass through this
    // before being appended, or the statement silently breaks.
    public func sql_escape(s : &string) : string {
        var out = string()
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.get(i)
            if(c == '\'') {
                out.append('\'')
                out.append('\'')
            } else {
                out.append(c)
            }
            i = i + 1
        }
        return out
    }

    // Format an f64 with two decimal places (repository-local copy of
    // underlayer_learning::f64_to_string — the repository layer sits below
    // learning and must not import it).
    public func f64_to_string(val : f64) : string {
        var int_part = val as i64
        var frac_part = ((val - (int_part as f64)) * 100.0) as i64
        var result = underlayer_core::int_to_string(int_part)
        result.append_view(".")
        var frac_str = underlayer_core::int_to_string(frac_part)
        result.append_view(frac_str.to_view())
        return result
    }

}
