// underlayer_web — Learning loop handlers (lesson view recording).
// Drives concept_states from real course reading. Anonymous requests are a no-op.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // POST /api/learning/view — mark a concept as viewed/studied.
    // Body: {"course_id":"elf","concept_id":"bytes"}
    //
    // WHY THIS ENDPOINT EXISTS AT ALL, when nothing on the platform called it
    // for nine of every ten lesson pages.  31 of the 438 page builders in
    // content/src carried their own hand-written copy of the fetch below, in
    // the page's own #js block.  The other 407 -- every HAT page, every
    // a64/jvm/mem/smp page, every landing page that draws its own navbar --
    // reported nothing, so the read side, FSRS scheduling, streaks,
    // achievements and analytics all depended on an event that most of the
    // collection never produced.  The fix is not 407 copies of this fetch; it
    // is the one call in content/src/lesson_nav.ch that every page already
    // makes.  See content/src/lesson_engagement.ch.
    public func handle_learning_view(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var anon = string("{\"ok\":true,\"recorded\":false}")
            send_json_str(res, &raw anon)
        } else {
            var body_str = read_body(&raw mut req)
            if(body_str.size() == 0) {
                var err = string("empty request body")
                send_error(res, 400u, &err)
            } else {
                var parse_result = json::parse(body_str.to_view())
                if(parse_result is std::Result.Err) {
                    var err = string("invalid JSON")
                    send_error(res, 400u, &err)
                } else {
                    var Ok(parsed) = parse_result else unreachable
                    var course_id = json_get_str(&raw parsed, "course_id")
                    var concept_id = json_get_str(&raw parsed, "concept_id")
                    if(concept_id.size() == 0 || course_id.size() == 0) {
                        var err = string("course_id and concept_id are required")
                        send_error(res, 400u, &err)
                    } else {
                        record_concept_read(db, &learner_id, &course_id, &concept_id, res)
                    }
                }
            }
        }
    }

    // The write, split out from the HTTP so a second entry point (a preview
    // build, a test) can record a read without a request.
    //
    // `first_time` is returned, and it is the difference between "a page made
    // a request" and "the platform learned something new".  Before this,
    // re-reading a concept returned `{"recorded":true}` every single time,
    // which is true and useless: the learner's own strip said "logged" whether
    // or not the server had seen the concept before.  Now the first read of a
    // concept says first_time:true and every read after it says false, and the
    // page says "Logged" or "Seen 3 times" accordingly.
    public func record_concept_read(
        db : *DbClient,
        learner_id : &string,
        course_id : &string,
        concept_id : &string,
        res : *mut http::ResponseWriter
    ) {
        var state = underlayer_repository::get_concept_state(db, learner_id, concept_id, course_id)
        var first_time = state.last_studied == 0
        var times_seen = state.attempts
        state.learner_id = learner_id.copy()
        state.concept_id = concept_id.copy()
        state.course_id = course_id.copy()
        var not_started = string("not_started")
        if(state.status.size() == 0) { state.status = string("learning") }
        else if(state.status.equals(&not_started)) { state.status = string("learning") }
        state.last_studied = underlayer_core::current_timestamp()
        underlayer_repository::upsert_concept_state(db, &raw state)
        underlayer_repository::record_activity(db, learner_id)
        // "Which course am I taking" has to be an answer, not an inference.
        // enrollments existed and had a full CRUD layer; nothing ever wrote to
        // it, so the table was empty for every learner on the platform.
        underlayer_repository::touch_enrollment(db, learner_id, course_id)
        underlayer_repository::run_achievement_checks(db, learner_id)
        var ok = string("{\"ok\":true,\"recorded\":true,\"status\":\"")
        ok.append_string(&state.status)
        ok.append_view("\",\"first_time\":")
        if(first_time) { ok.append_view("true") } else { ok.append_view("false") }
        ok.append_view(",\"concept_id\":\"")
        ok.append_string(concept_id)
        ok.append_view("\",\"course_id\":\"")
        ok.append_string(course_id)
        ok.append_view("\",\"times_seen\":")
        ok.append_string(&underlayer_core::int_to_string(times_seen as i64))
        ok.append_view("}")
        send_json_str(res, &raw ok)
    }

}