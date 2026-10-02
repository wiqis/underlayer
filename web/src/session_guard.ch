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
using underlayer_db::DbClient

public namespace underlayer_web {

    // Returns true when the caller may act on `session_id`.  On false the
    // response has already been written.
    public func require_own_session(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter, session_id : *string) : bool {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var sid = session_id.copy()
        if(underlayer_repository::session_belongs_to(db, &sid, &learner_id)) {
            return true
        }
        var err = string("this session belongs to another learner")
        send_error(res, 403u, &err)
        return false
    }

}