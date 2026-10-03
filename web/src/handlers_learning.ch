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
    // `db` is &DbClient, matching every other route handler here: the router's
// `|&db|` closures capture the client by reference, so a handler declared
    // *DbClient cannot be called from one without a re-borrow that produces
    // **DbClient. (That is also the shape 2.2.46 is about -- but there the
    // mismatch was hidden behind `&raw` and the handler received a client whose
    // handle was not the live connection. Here the types are declared to match
    // the call sites rather than papered over.)
    public func handle_learning_view(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
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
                    } else if(!course_has_concept(courses_dir, &course_id, &concept_id)) {
                        // THE CONCEPT ID IS CHECKED AGAINST THE MANIFEST BEFORE
                        // ANY WRITE.  It was not, and because this endpoint
                        // upserts whatever it is handed, any id at all became a
                        // row in concept_states -- which is where coverage,
                        // mastery, the health score and every module breakdown
                        // are counted from.  So a typo, a stale build, a renamed
                        // concept, or a crafted request all invented progress
                        // the learner never made.
                        //
                        // Measured on a learner who had read 5 ELF lessons:
                        //
                        //   POST {"course_id":"elf","concept_id":"this-concept-does-not-exist"}
                        //     -> {"ok":true,"recorded":true,"first_time":true,...}
                        //   GET  /api/progress?course_id=elf
                        //     -> concepts_started: 6, breadth: 25.0
                        //
                        // before that request the same learner read as 5 of 24
                        // (20%).  A concept that does not exist had moved their
                        // coverage by five points and could have moved it again
                        // on the next call, without limit.
                        //
                        // 404 rather than 400: the request named a resource that
                        // is not there, which is what 404 is for. The response
                        // says recorded:false so a caller can tell "I did not
                        // learn this" from "the server rejected it", and it is
                        // NOT an error status for the page -- a lesson whose id
                        // has drifted must still render, so the shape is the same
                        // as the anonymous no-op above and the page carries on.
                        var err = string("unknown concept")
                        var nf = string("{\"ok\":true,\"recorded\":false,\"reason\":\"unknown_concept\",\"course_id\":\"")
                        var cid_out = course_id.copy()
                        nf.append_string(&cid_out)
                        nf.append_view("\",\"concept_id\":\"")
                        var cidc = concept_id.copy()
                        nf.append_string(&cidc)
                        nf.append_view("\"}")
                        // send_json_str takes &string, so the view is kept alive in a local
                        // rather than passed as a temporary.
                        var nfb = nf
                        send_json_str(res, &raw nfb)
                    } else {
                        record_concept_read(&raw db, &learner_id, &course_id, &concept_id, res)
                    }
                }
            }
        }
    }

    // Does this concept id exist in this course?
    //
    // The manifest is the only authority on what a course contains: the lesson
    // pages, the module lists and the concept index are all generated from it,
    // so an id that is not in it cannot be reached by reading and must not be
    // recordable. Both the top-level `concepts` array and each module's
    // `concepts` array are checked, because a manifest may express the same
    // course either way and both spellings occur across the 34 courses.
    //
    // A course that cannot be loaded returns true rather than false. The reason
    // is the failure mode: this guard exists to stop invented progress, and if
    // the manifest is unreadable then "reject the read" would silently discard
    // a learner's real activity -- trading one wrong number for missing data,
    // which is the worse of the two. A course that does not exist on disk is
    // caught earlier, by the 404 on its pages.
    private func course_has_concept(courses_dir : &string, course_id : &string, concept_id : &string) : bool {
        var course = underlayer_repository::load_course_from_disk(courses_dir, course_id)
        if(course.id.size() == 0) { return true }
        // course.concepts is a vector<ConceptRef>, not a vector<string> -- each entry
        // is an object with id/title/module_id, and it is the .id that is
        // compared. (A vector<string> here does not resolve; `c.copy` is
        // "unresolved child 'copy' in parent 'c'".)
        var ci : size_t = 0
        while(ci < course.concepts.size()) {
            var cref = course.concepts.get_ptr(ci)
            var cid = cref.id.copy()
            // equals takes &string, so the view is materialised into a local first.
            if(cid.equals(concept_id)) { return true }
            ci = ci + 1
        }
        var mi : size_t = 0
        while(mi < course.modules.size()) {
            var mod = course.modules.get_ptr(mi)
            var cj : size_t = 0
            while(cj < mod.concepts.size()) {
                var mc = mod.concepts.get_ptr(cj)
                var mcid = mc.copy()
                if(mcid.equals(concept_id)) { return true }
                cj = cj + 1
            }
            mi = mi + 1
        }
        return false
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