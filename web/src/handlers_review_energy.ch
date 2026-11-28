// underlayer_web — G4 energy-after persistence.
//
// The check-in is two writes: energy_before + chosen duration on
// /api/review/start (handlers_review.ch), and energy_after here. Keeping the
// second write separate means a learner who finishes on a different page can
// still record how they felt without re-posting a rating.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_review_energy(db : *DbClient, req : &http::Request) : http::Response {
        var body = read_body(req)
        if(body.size() == 0) {
            var empty = string("empty request body")
            return send_error(400u, &empty)
        }
        var pr = json::parse(body.to_view())
        if(pr is std::Result.Err) {
            var bad = string("invalid JSON")
            return send_error(400u, &bad)
        }
        var Ok(parsed) = pr else unsafe { unreachable }
        var session_id = json_get_str(&parsed, "session_id")
        var energy_after = json_get_str(&parsed, "energy_after")
        if(session_id.size() == 0 || energy_after.size() == 0) {
            var missing = string("session_id and energy_after are required")
            return send_error(400u, &missing)
        }
        var allowed = string("ready okay low-energy")
        if(!allowed.contains(&energy_after.to_view())) {
            var invalid = string("energy_after must be ready, okay or low-energy")
            return send_error(400u, &invalid)
        }
        var guard = require_own_session(db, req, &session_id)
        if(guard is std::Option.Some) {
            var Some(refusal) = guard else unsafe { unreachable }
            return refusal
        }
        if(!save_review_energy_after(db, &session_id, &energy_after)) {
            var unknown = string("session not found")
            return send_error(404u, &unknown)
        }
        var out = string("{\"ok\":true,\"session_id\":\"")
        var e = underlayer_core::json_escape(&session_id.to_view())
        out.append_string(&e)
        out.append_view("\"}")
        return send_json_str(&out)
    }

}
