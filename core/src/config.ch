// underlayer_core — runtime configuration that has no compile-time default
// other than "off" (H9 operator identity, H17 staged-rollout kill switches).
//
// WHY THESE ARE FUNCTIONS, NOT GLOBALS.  A `@never_destructed string` global is
// zero-initialised, not constructed, and reads back EMPTY at request time
// (measured on this codebase); a constructed global is a bitwise copy that
// aliases a freed buffer.  Reading `getenv` on demand is the pattern already
// used by `account_url()` and `build_info.ch`, and it is the only one that
// cannot go stale after a config change.
//
// H9: `UL_OPERATOR_IDS` is a comma-separated allow-list of STABLE identities —
// the local learner id and/or the `account_user_id` from the shared account.
// It is a secret-store value, never a request parameter.  There is no `role`
// column on `learners` and this file does not add one.
//
// H17: both flags default OFF.  OFF means "no new paid gating, no v2 surface
// mutation" — the shipped behaviour is preserved byte-for-byte.  Flipping a
// flag changes behaviour on the next request with no rebuild.
using std::string
using std::string_view

public namespace underlayer_core {

    // Length-independent comparison: walk the longer of the two inputs even
    // when a mismatch is found early, and fold the length difference in at the
    // end.  Used only for allow-list membership; no early `return false` that
    // would leak which character matched.
    public func constant_time_equals(a : &std::string_view, b : &std::string_view) : bool {
        var diff : i64 = 0
        var n = a.size()
        if(b.size() > n) { n = b.size() }
        var i : size_t = 0
        while(i < n) {
            var ca : i64 = 0
            var cb : i64 = 0
            if(i < a.size()) { ca = a.at(i) as i64 }
            if(i < b.size()) { cb = b.at(i) as i64 }
            diff = diff | (ca ^ cb)
            i = i + 1
        }
        if(a.size() != b.size()) { diff = diff | 1 }
        return diff == 0
    }

    private func truthy(v : &std::string_view) : bool {
        // Deliberately explicit: accepted spellings are 1, true, yes and on
        // (any case).  An empty or unknown value is OFF, never a guess.
        if(v.equals(string_view("1"))) { return true }
        if(v.equals(string_view("true"))) { return true }
        if(v.equals(string_view("True"))) { return true }
        if(v.equals(string_view("TRUE"))) { return true }
        if(v.equals(string_view("yes"))) { return true }
        if(v.equals(string_view("Yes"))) { return true }
        if(v.equals(string_view("YES"))) { return true }
        if(v.equals(string_view("on"))) { return true }
        if(v.equals(string_view("On"))) { return true }
        if(v.equals(string_view("ON"))) { return true }
        return false
    }

    public func flag_enabled(name : *char) : bool {
        var raw = get_env_str(name)
        if(raw.empty()) { return false }
        var view = raw.to_view()
        return truthy(&view)
    }

    // H17 kill switches. Both are OFF unless explicitly enabled in the deploy
    // environment; the names are part of the deploy contract in
    // docs/deployment.md §5k.
    public func paid_gating_enabled() : bool {
        return flag_enabled("UL_PAID_GATING_ENABLED")
    }

    public func learner_surface_v2() : bool {
        return flag_enabled("UL_LEARNER_SURFACE_V2")
    }

    // One additive "on"/"off" token for /api/health, so a flag rehearsal is
    // observable on the wire without rebuilding or adding a route.
    public func flag_state(enabled : bool) : string {
        if(enabled) { return string("on") }
        return string("off")
    }

    // H9: is `identity` one of the configured operators? Every entry is
    // compared (no early exit) and the list is read from the environment on
    // each call, so a rotation takes effect without a restart of the config
    // object. Whitespace around comma-separated entries is ignored.
    public func is_operator(identity : &std::string) : bool {
        if(identity.empty()) { return false }
        var allow = get_env_str("UL_OPERATOR_IDS")
        if(allow.empty()) { return false }
        var view = allow.to_view()
        var idv = identity.to_view()
        var matched = false
        var start : size_t = 0
        while(start <= view.size()) {
            var end = start
            while(end < view.size() && view.at(end) != ',') { end = end + 1 }
            var s = start
            while(s < end && (view.at(s) == ' ' || view.at(s) == '\t')) { s = s + 1 }
            var e = end
            while(e > s && (view.at(e - 1) == ' ' || view.at(e - 1) == '\t')) { e = e - 1 }
            if(e > s) {
                var entry = view.subview(s, e)
                if(constant_time_equals(&entry, &idv)) { matched = true }
            }
            if(end >= view.size()) { return matched }
            start = end + 1
        }
        return matched
    }

}
