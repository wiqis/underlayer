// underlayer_repository — session ownership.
//
// WHY THIS FILE EXISTS.  Every `POST /api/session/*` endpoint takes a
// `session_id` straight from the query string and acts on it, and session ids
// are Unix timestamps:
//
//     var session_id = underlayer_core::int_to_string(now)   // "1790930967"
//
// so the whole id space of a given day is enumerable by addition, and nothing
// checked that the session belonged to the caller.  Proven against the running
// server: an anonymous request with NO Authorization header at all
//
//     POST /api/session/abort?session_id=1790930967   -> 200 {"state":"aborted"}
//
// deleted another learner's active session row.  pause/resume/undo/skip do the
// same to a live session.  That is an object-level authorization failure, and it
// is not a subtle one.
//
// THE CHECK IS OWNERSHIP AGAINST THE RESOLVED LEARNER, NOT "HAS A TOKEN".
// The rest of the platform resolves an anonymous visitor to the shared `demo`
// learner so that signed-out pages still render (see the `string("demo")`
// fallbacks in handlers_progress.ch and elsewhere).  This check keeps that
// behaviour intact and only refuses a session that does not belong to whoever
// the caller turned out to be.  An anonymous caller may therefore still drive
// the demo learner's own session -- exactly as before -- and can no longer touch
// a signed-in learner's.  Requiring a token instead would have fixed the hole
// and broken the signed-out review flow, which is a behaviour change this fix
// has no business making.
//
// Returning 403 rather than 404 is deliberate: these are state-changing calls
// where "forbidden" is the true answer, and a 404 would be a lie the client
// would have to special-case.
using std::string
using underlayer_db::DbClient

public namespace underlayer_repository {

    // True when `session_id` exists and its learner_id is `learner_id`.
    // An empty learner_id never matches: an unresolved caller owns nothing.
    public func session_belongs_to(db : *DbClient, session_id : &string, learner_id : &string) : bool {
        if(session_id.size() == 0) { return false }
        if(learner_id.size() == 0) { return false }
        var sid = sql_escape(session_id)
        var lid = sql_escape(learner_id)
        var sql = string("SELECT learner_id FROM sessions WHERE id = '")
        sql.append_string(&sid)
        sql.append_view("' LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() == 0) { return false }
        var row = result.rows.get_ptr(0)
        if(row.vals.size() < 1) { return false }
        var owner = row.vals.get_ptr(0).copy()
        return owner.equals(learner_id)
    }

}