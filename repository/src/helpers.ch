// underlayer_repository — Shared helpers (public for cross-file use).
using std::string
using std::string_view

public namespace underlayer_repository {

    public func parse_i64(v : std::string_view) : i64 {
        var result : i64 = 0
        var negative = false
        var i : size_t = 0
        if(v.size() > 0 && v.at(0) == '-') { negative = true; i = 1 }
        while(i < v.size()) {
            var c = v.at(i)
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
        if(v.size() > 0 && v.at(0) == '-') { negative = true; i = 1 }
        // Integer part
        while(i < v.size()) {
            var c = v.at(i)
            if(c >= '0' && c <= '9') { result = result * 10.0 + ((c as i64 - 48) as f64) }
            else if(c == '.') { i = i + 1; break }
            i = i + 1
        }
        // Fractional part
        var frac_mult : f64 = 0.1
        while(i < v.size()) {
            var c = v.at(i)
            if(c >= '0' && c <= '9') {
                result = result + ((c as i64 - 48) as f64) * frac_mult
                frac_mult = frac_mult * 0.1
            }
            i = i + 1
        }
        if(negative) { result = -result }
        return result
    }

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

    // Number of elements in an array node (0 when the node is not an array).
    public func json_len(node : &JsonValue) : size_t {
        switch(node) {
            Array(values) => { return values.size() }
            default => { return 0 }
        }
    }

    // Element `i` of an array node.
    public func json_at(node : &JsonValue, i : size_t) : std::Option<&JsonValue> {
        switch(node) {
            Array(values) => {
                if(i >= values.size()) { return std::Option.None<&JsonValue>() }
                return values.get(i)
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
    // A 32-hex-character random identifier: 16 random bytes, hex encoded.
    //
    // This exists because the same twelve-line sequence had been copied into
    // every repository file that mints an id.  One implementation is also one
    // place where the randomness source has to be right, instead of ten; the
    // implementation itself lives in `core`, so the web layer can mint ids too.
    public func random_hex_id() : string {
        return underlayer_core::random_hex_id()
    }

    // Escape a string for embedding inside a single-quoted SQL literal:
    // ' becomes '' (standard SQL escaping). The codebase builds SQL by string
    // concatenation, so any user/manifest-supplied text must pass through this
    // before being appended, or the statement silently breaks.
    public func sql_escape(s : &string) : string {
        var out = string()
        var i : size_t = 0
        while(i < s.size()) {
            var c = s.at(i)
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

    // Format an f64 for SQL. Repository-local copy of the learning-layer
    // formatter — the repository layer sits below learning and must not import
    // it. Kept in step with learning/src/utils.ch deliberately: two copies of
    // "number to text" is one too many, and the two have already disagreed once
    // (this one gained zero-padding while that one had not).
    //
    // FOUR decimals, not two, and the reason is the FSRS round trip.
    // `review_items.stability` is written here and read back by the scheduler
    // on the next rating. S0("Good") is w[3] = 0.1901 and the next-stability
    // formula grows it through 0.1985 and 0.2080 -- all below 0.20. At two
    // decimals every one of those is "0.19", so the value was rounded flat on
    // the way in and the scheduler read the same number forever: ten successful
    // reviews moved stability from 0.19 to 0.19. Two decimals is right for a
    // figure a person reads and wrong for a value the next step depends on.
    public func f64_to_string(val : f64) : string {
        return f64_to_string_prec(val, 4)
    }

    public func f64_to_string_prec(val : f64, places : i64) : string {
        var int_part = val as i64
        var scale = 1.0
        var k : i64 = 0
        while(k < places) { scale = scale * 10.0; k = k + 1 }
        var frac_part = ((val - (int_part as f64)) * scale) as i64
        var result = underlayer_core::int_to_string(int_part)
        result.append_view(".")
        // Zero-pad, or a small fraction produces a MALFORMED number rather than
        // a rounded one: 0.05 at two places came out as "0.5" -- ten times the
        // value -- because the single digit was appended with no tens place.
        var pad = places - 1
        while(pad > 0) {
            if(frac_part < 100) { result.append_view("0") }
            pad = pad - 1
        }
        var frac_str = underlayer_core::int_to_string(frac_part)
        result.append_view(frac_str.to_view())
        return result
    }

}
