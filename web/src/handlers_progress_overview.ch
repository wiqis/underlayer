// underlayer_web — HTTP wrappers for the two new read endpoints.
//
// They exist as wrappers rather than being wired straight to the builders in
// handlers_progress_json.ch because a handler is where the authenticated
// learner is resolved, and resolving it is the same two lines in both and must
// not drift: the whole point of these endpoints is that they report the
// SIGNED-IN learner's history and not a shared "demo" row.
//
// No SQL here and no JSON string building here.  Builders and queries live in
// handlers_progress_json.ch and repository/src/exercise_attempts.ch.
using std::string
using underlayer_db::DbClient

public namespace underlayer_web {

    // GET /api/me/overview
    // {learner_id, courses:[{course_id,title,concepts_total,concepts_started,
    //  concepts_mastered,concepts_due,progress_percentage,mastery_percentage,
    //  enrolled_at,last_accessed,status}], courses_total, concepts_started_all,
    //  concepts_total_all, failed_exercises_count, failed_exercises:[...]}
    public func handle_my_overview(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        var anon = false
        if(learner_id.size() == 0) {
            // Signed out: an empty list is the truth, not the demo learner's
            // history.  Falling back to "demo" here would show a stranger's
            // courses and failures to anyone who opened /dashboard, which is
            // worse than showing nothing.
            learner_id = string("demo")
            anon = true
        }
        if(anon) {
            var empty = string("{\"learner_id\":\"\",\"courses\":[],\"courses_total\":0,\"concepts_started_all\":0,\"concepts_total_all\":0,\"failed_exercises_count\":0,\"failed_exercises\":[],\"anonymous\":true}")
            send_json_str(res, &raw empty)
            return
        }
        var body = build_overview_json(&raw db, courses_dir, &learner_id)
        send_json_str(res, &raw body)
    }

    // GET /api/exercises/failures
    // {learner_id, failed_exercises:[{exercise_id,concept_id,course_id,misses,
    //  last_missed,question,lesson_url}]}
    public func handle_exercise_failures(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) {
            var empty = string("{\"learner_id\":\"\",\"failed_exercises\":[],\"anonymous\":true}")
            send_json_str(res, &raw empty)
            return
        }
        var limit : i64 = 25
        var q = string("limit")
        var v = req.query.get(&q.to_view())
        if(v.size() > 0) {
            var parsed = underlayer_repository::parse_i64(v)
            if(parsed > 0) { limit = parsed }
            if(limit > 100) { limit = 100 }
        }
        var body = build_failures_json(&raw db, &learner_id, limit)
        send_json_str(res, &raw body)
    }

}