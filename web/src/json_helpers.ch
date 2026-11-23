// underlayer_web — JSON body helpers.
//
// Request bodies are parsed once into an owned `JsonValue`, and the handlers
// read fields out of it by reference.  The functions here are thin names for
// the repository ones, which own the actual matching logic: one implementation
// of "read a field" instead of two that can drift (this file and
// `repository/src/helpers.ch` had already drifted — this copy tested
// `obj is JsonValue.Object` on a raw pointer).
//
// `*char` keys are C string literals ("rating", "concept_id"); that conversion
// happens in the repository helpers.
using std::string

public namespace underlayer_web {

    public func json_get(obj : &JsonValue, key : *char) : std::Option<&JsonValue> {
        return underlayer_repository::json_get(obj, key)
    }

    public func json_str(val : &JsonValue) : string {
        return underlayer_repository::json_str(val)
    }

    public func json_get_str(obj : &JsonValue, key : *char) : string {
        return underlayer_repository::json_get_str(obj, key)
    }

    public func json_int(val : &JsonValue) : i64 {
        return underlayer_repository::json_i64(val)
    }

    public func json_get_int(obj : &JsonValue, key : *char) : int {
        return underlayer_repository::json_get_int(obj, key)
    }

    public func json_get_bool(obj : &JsonValue, key : *char) : bool {
        return underlayer_repository::json_get_bool(obj, key)
    }

    // Field as string, tolerant of JSON numbers (e.g. {"rating":3}) — renders
    // the number's literal text. Returns "" for null/missing/other types.
    public func json_get_str_or_num(obj : &JsonValue, key : *char) : string {
        var found = json_get(obj, key)
        if(found is std::Option.None) { return string() }
        var Some(node) = found else unsafe { unreachable }
        switch(node) {
            String(s) => { return s.copy() }
            Number(n) => { return n.copy() }
            default => { return string() }
        }
    }

}
