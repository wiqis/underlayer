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

}
