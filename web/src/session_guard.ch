// underlayer_web — one ownership gate for every endpoint that acts on a
// caller-supplied session_id.
//
// WHY A HELPER RATHER THAN SEVEN COPIES OF THE SAME FOUR LINES.  The IDOR this
// closes was present on all of pause, resume, abort, undo, skip, session-detail
// and review-end at once, and it was present because each handler did the same
// thing independently: read `session_id` from the query string and hand it to a
// repository function.  Fixing them one at a time would fix six of seven and
// leave the seventh as the next hole, which is exactly what happened before.
// One gate, called by every session-scoped handler, is the shape that stays
// fixed.
//
// WHAT IT DOES.  Resolves the caller the way the rest of the platform does --
// bearer token, else the shared `demo` learner -- and then insists the session
// belongs to that learner.  It writes the 403 and returns false; the caller
// returns immediately.  See repository/src/session_ownership.ch for why the
// gate is ownership rather than authentication.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // `None` when the caller may act on `session_id`; `Some(response)` when it
    // may not, and that response is the 403 to send.
    public func require_own_session(db : *DbClient, req : &http::Request, session_id : &string) : std::Option<http::Response> {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var sid = session_id.copy()
        if(underlayer_repository::session_belongs_to(db, &sid, &learner_id)) {
            return std::Option.None<http::Response>()
        }
        var err = string("this session belongs to another learner")
        return std::Option.Some<http::Response>(send_error(403u, &err))
    }

    // ---- H9: operator gate -------------------------------------------------
    // A SECOND kind of guard, deliberately in the same file so no handler can
    // invent a third. Ownership above answers "does this row belong to the
    // caller"; this one answers "is the caller an operator at all". There is no
    // role column: the identity is resolved from the session by the repository
    // and checked against the secret-store UL_OPERATOR_IDS allow-list.

    // The request id echoed by the access log. A valid caller-supplied value
    // is the SAME one delivery uses, so audit rows and [request] lines join.
    public func operator_request_id(req : &http::Request) : string {
        var got = req.headers.get(string_view("X-Request-Id"))
        if(got is std::Option.Some) {
            var Some(value) = got else unsafe { unreachable }
            if(value.size() > 0 && value.size() <= 64) {
                var safe = true
                var i : size_t = 0
                while(i < value.size()) {
                    var c = value.at(i)
                    var ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                             (c >= '0' && c <= '9') || c == '-' || c == '_' ||
                             c == '.' || c == ':'
                    if(!ok) { safe = false }
                    i = i + 1
                }
                if(safe) { return value.to_string() }
            }
        }
        return underlayer_core::random_hex(8)
    }

    // None = allowed AND audited. Some = the refusal to send.
    public func require_operator(db : *DbClient, req : &http::Request, action : &string, details : &string) : std::Option<http::Response> {
        var learner_id = auth_get_learner_id(db, req)
        var actor = underlayer_repository::operator_identity(db, &learner_id)
        if(actor.empty()) {
            if(learner_id.empty()) {
                var anon = string("unauthorized")
                return std::Option.Some<http::Response>(send_error(401u, &anon))
            }
            var msg = string("operator allow-list does not include this account")
            return std::Option.Some<http::Response>(send_error(403u, &msg))
        }
        var rid = operator_request_id(req)
        var peer = req.remote.copy()
        underlayer_repository::write_operator_audit(db, &actor, &rid, &peer, action, details)
        return std::Option.None<http::Response>()
    }

    // H17: additive flag snapshot used at route/UI entry points. Both flags are
    // read from the environment on each call; no rebuild is needed to flip one.
    public func rollout_flags_json() : string {
        var body = string("\"paid_gating_enabled\":\"")
        var paid = underlayer_core::flag_state(underlayer_core::paid_gating_enabled())
        body.append_view(paid.to_view())
        body.append_view("\",\"learner_surface_v2\":\"")
        var v2 = underlayer_core::flag_state(underlayer_core::learner_surface_v2())
        body.append_view(v2.to_view())
        body.append('"')
        return body
    }

}