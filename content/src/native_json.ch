// underlayer_content — JSON fragment helpers for the native lesson contract.
//
// This is JSON, not markup: append_view is the established pattern and there
// is no #html/#css/#js here.  There is ONE escaper in the product —
// underlayer_core::json_escape — so this file never writes a second one.
using std::string
using std::string_view
using std::vector

public namespace underlayer_content {

    // A quoted JSON string. json_escape handles quotes, backslashes and
    // control characters; all text reaching here is already plain text.
    public func jquote(s : &string) : string {
        var out = string("\"")
        var v = s.to_view()
        var escaped = underlayer_core::json_escape(&v)
        out.append_string(&escaped)
        out.append('"')
        return out
    }

    public func jint(v : i64) : string {
        return underlayer_core::int_to_string(v)
    }

    public func jbool(v : bool) : string {
        if(v) { return string("true") }
        return string("false")
    }

    public func jnull_or_string(s : &string) : string {
        if(s.size() == 0) { return string("null") }
        return jquote(s)
    }

    public func jpair(key : std::string_view, value : &string) : string {
        var out = string("\"")
        out.append_view(&key)
        out.append_view("\":")
        out.append_string(value)
        return out
    }

    // An array whose elements are already complete JSON fragments.
    public func jarray(items : &vector<string>) : string {
        var out = string("[")
        var i : size_t = 0
        while(i < items.size()) {
            if(i > 0) { out.append_view(",") }
            out.append_string(items.at_ref(i))
            i = i + 1
        }
        out.append_view("]")
        return out
    }

    public func jstring_array(items : &vector<string>) : string {
        var quoted = vector<string>()
        var i : size_t = 0
        while(i < items.size()) {
            quoted.push(jquote(items.at_ref(i)))
            i = i + 1
        }
        return jarray(&quoted)
    }

    // Digits from JourneyFacts.minutes (a string) into a JSON integer.
    // No guessing: a non-numeric value is 0.
    public func jdigits(s : &string) : i64 {
        var out : i64 = 0
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
            if(c < '0' || c > '9') { i = i + 1; continue }
            out = out * 10 + (c as i64 - 48)
            i = i + 1
        }
        return out
    }
}
