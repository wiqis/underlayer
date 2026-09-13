// underlayer_web — JSON parsing helpers.
using std::string
using underlayer_models::JsonValue

public namespace underlayer_web {

    public func json_get(obj : *JsonValue, key : *char) : *mut JsonValue {
        if(obj == null) { return null }
        if(!(obj is JsonValue.Object)) { return null }
        var Object(map) = *obj else unreachable
        var k = string::make_no_len(key)
        return map.get_ptr(&k)
    }

    public func json_str(val : *JsonValue) : string {
        if(val == null) { return string() }
        if(val is JsonValue.String) {
            var String(s) = *val else unreachable
            return s.copy()
        }
        return string()
    }

    public func json_get_str(obj : *JsonValue, key : *char) : string {
        var field = json_get(obj, key)
        return json_str(field)
    }

    public func json_int(val : *JsonValue) : i64 {
        if(val == null) { return 0 }
        if(val is JsonValue.Number) {
            var Number(s) = *val else unreachable
            var result : i64 = 0
            var negative = false
            var i : size_t = 0
            if(s.size() > 0 && s.get(0) == '-') { negative = true; i = 1 }
            while(i < s.size()) {
                var c = s.get(i)
                if(c >= '0' && c <= '9') { result = result * 10 + (c as i64 - 48) }
                i = i + 1
            }
            if(negative) { result = -result }
            return result
        }
        return 0
    }

    public func json_get_int(obj : *JsonValue, key : *char) : int {
        var field = json_get(obj, key)
        return json_int(field) as int
    }

}
