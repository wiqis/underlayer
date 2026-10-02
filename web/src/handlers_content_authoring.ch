// underlayer_web — COURSE CONTENT WRITES, refused.
//
// WHAT WAS OPEN, MEASURED ON 2026-10-02 AGAINST THE RUNNING SERVER.
//
// With no Authorization header at all:
//
//     POST /api/exercises/import
//       {"exercises":[{"course_id":"elf","concept_id":"bytes","type":"mcq",
//                      "question":"INJECTED BY UNAUTHENTICATED CALLER",
//                      "answer":"a","options":"alpha|beta","correct_index":0}]}
//       -> {"inserted":1,"errors":0}
//       -> the row is in the `exercises` table
//
// `exercises` is not a per-learner table.  It is the global bank every learner
// on the platform is graded against, so this endpoint let an anonymous caller
// write the questions and the answer key.  Two calls were also unauthenticated:
// POST /api/exercises/seed (which repopulates the bank from the manifests and
// so can overwrite it) and POST /api/reviews/:id/helpful.
//
// WHY REFUSED RATHER THAN SIMPLY AUTHENTICATED, which is the same reasoning as
// web/src/handlers_feedback_admin.ch and for the same reason.  Adding a token
// check would have turned this from "anybody" into "any registered learner",
// which is the same defect with a login in front of it: an account is free, and
// the ability to rewrite the course is not something a free account should
// carry.
//
// WHY THERE IS NOBODY TO GIVE IT TO.  The `learners` table is
// (id, name, email, password_hash, created_at).  There is no role column, no
// is_admin flag and no membership table -- handlers_feedback_admin.ch already
// recorded that, and the finding still holds.  A content author is not something
// this codebase can currently express, so the honest answer is that this
// capability is unreachable, said out loud in the error body rather than left to
// be discovered later.
//
// WHAT THE PLATFORM LOSES, STATED PLAINLY.  Course exercises can no longer be
// pushed over HTTP.  They are still seeded from the course manifests at startup
// (repository/src/seed_exercises_from_manifest, called from init_schema), which
// is the path the shipped content actually arrives by -- so nothing that works
// today stops working.  What stops is the ability to inject content from outside
// the repository.
//
// THE ROUTES STAY REGISTERED, on purpose.  They are reachable, they answer, and
// they say why they refuse.  Deleting them would leave the same capability
// reachable through a different name, and would make the refusal invisible to
// anyone who finds the route in a status document.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // The one gate, so the three routes below cannot drift apart.
    // 401 when there is no token -- an anonymous caller, full stop.
    // 403 when there is one: the caller is known and still may not write course
    // content, because no role on this platform may.
    private func refuse_without_author_role(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var anon = string("unauthorized")
            send_error(res, 401u, &anon)
            return
        }
        var msg = string("no content-author role exists on this platform, so course exercises cannot be written over HTTP; they are seeded from the course manifests at startup instead")
        send_error(res, 403u, &msg)
    }

    // POST /api/exercises/import.  Named `refuse_` rather than shadowing
    // the original `handle_exercise_import`, which stays in
    // handlers_exercises_bulk.ch: two functions of one name in one namespace is
    // a compile error, and deleting the original would erase the record of what
    // the endpoint did.
    //
    // was: unauthenticated, and inserted
    // caller-supplied questions and answer keys into the global exercise bank.
    public func refuse_exercise_import(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        refuse_without_author_role(db, req, res)
    }

    // POST /api/exercises/seed -- was: unauthenticated, and repopulated the
    // global bank from a caller-supplied course id.
    public func refuse_exercise_seed(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        refuse_without_author_role(db, req, res)
    }

}