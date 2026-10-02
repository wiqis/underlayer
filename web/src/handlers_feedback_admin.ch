// underlayer_web — the feedback routes that would cross learners, all refused.
//
// WHAT THIS FILE IS.  Three routes and one update, each of which serves data
// belonging to every learner on the platform, and each of which now answers
// 403 to an authenticated caller and 401 to an anonymous one.  They are not
// deleted: the routes are registered, the repository queries behind them exist,
// and the day this platform grows a reviewer identity this file is where the
// gate changes and nothing else.
//
// WHY THEY ARE REFUSED RATHER THAN MERELY AUTHENTICATED.  All four took NO
// authentication at all before this change -- GET /api/feedback/admin answered
// 200 to an anonymous curl with every learner's feedback for every pending
// concept, GET /api/feedback/admin/reports answered 200 with every learner's
// exercise report, and PUT /api/feedback/:id/status let anybody mark anybody's
// feedback resolved or rejected.  Adding a token check to those three and
// calling the hole closed would have been wrong: one registered learner is
// enough, so it would have become "any learner reads all learners' feedback",
// which is the same defect with a login in front of it.
//
// WHY THERE IS NOBODY TO GIVE THEM TO.  The `learners` table is
// (id, name, email, password_hash, created_at).  There is no role column, no
// is_admin flag, no membership table, and handlers_settings.ch -- the file the
// brief pointed at for an admin role -- has no role concept in it either.  A
// named reviewer is not something this codebase can currently express, so the
// honest answer is that this capability is unreachable, said out loud in the
// error body rather than left to be discovered as an empty array.
//
// WHAT THE PLATFORM LOSES, STATED PLAINLY.  Nobody can read the corrections a
// learner filed about a lesson, and nobody can mark one resolved.  `status` and
// `admin_notes` are write-once for now.  A learner can always see their own
// feedback (GET /api/feedback/concept/:conceptId, owner-scoped); nobody else
// can.  That asymmetry is the cost, and it is real.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // The one gate, so that the four routes below cannot drift apart.
    // 401 when there is no token at all -- that is an anonymous caller, full
    // stop.  403 when there is a token: the caller is known and still may not
    // read across learners, because this platform has no role that may.
    private func refuse_without_reviewer_role(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var anon = string("unauthorized")
            send_error(res, 401u, &anon)
            return
        }
        var msg = string("no reviewer role exists on this platform, so cross-learner feedback is not readable; a learner can read their own feedback at GET /api/feedback/concept/:conceptId")
        send_error(res, 403u, &msg)
    }

    // GET /api/feedback/admin — was: every pending feedback row from every
    // learner, to anyone, including people with no account.
    public func handle_get_admin_feedback(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        refuse_without_reviewer_role(db, req, res)
    }

    // GET /api/feedback/admin/reports — was: every exercise report from every
    // learner, to anyone.
    public func handle_get_admin_reports(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        refuse_without_reviewer_role(db, req, res)
    }

    // PUT /api/feedback/:id/status — was: unauthenticated, and wrote to any
    // feedback row in the table by id.  `feedback_id` is deliberately unused:
    // the request is refused before the id is looked at, so a caller learns
    // nothing about which ids exist.
    public func handle_update_feedback_status(db : *DbClient, feedback_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        refuse_without_reviewer_role(db, req, res)
    }

}
