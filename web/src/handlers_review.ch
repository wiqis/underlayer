// underlayer_web — Review session handlers.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::ReviewItem
using underlayer_models::ConceptState
using underlayer_learning::ReviewState

public namespace underlayer_web {

    public func handle_review_start(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")

        var due_items = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, 10)

        var now = underlayer_core::current_timestamp()
        var session_id = underlayer_core::int_to_string(now)
        underlayer_repository::create_session(&raw db, &raw session_id, &raw learner_id, now)

        var body = std::string("{\"session_id\":\"")
        body.append_string(&session_id)
        body.append_view("\",\"items\":[")
        var i : size_t = 0
        while(i < due_items.size()) {
            if(i > 0) { body.append_view(",") }
            var item = due_items.get_ptr(i)
            body.append_view("{\"id\":\"")
            body.append_string(&item.id)
            body.append_view("\",\"concept\":\"")
            body.append_string(&item.concept_id)
            body.append_view("\",\"type\":\"")
            body.append_string(&item.item_type)
            body.append_view("\",\"front\":\"")
            body.append_string(&item.front)
            body.append_view("\",\"back\":\"")
            body.append_string(&item.back)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("],\"total\":")
        var total_str = underlayer_core::int_to_string(due_items.size() as i64)
        body.append_string(&total_str)
        body.append_view(",\"started_at\":")
        body.append_string(&session_id)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    public func handle_review_submit(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var q_cid = string("concept_id")
        var q_crsid = string("course_id")
        var q_rat = string("rating")
        var q_sid = string("session_id")
        var q_time = string("time_spent_ms")
        var cid_v = req.query.get(&q_cid.to_view())
        var crsid_v = req.query.get(&q_crsid.to_view())
        var rat_v = req.query.get(&q_rat.to_view())
        var sid_v = req.query.get(&q_sid.to_view())
        var time_v = req.query.get(&q_time.to_view())
        if(cid_v.size() == 0 || crsid_v.size() == 0 || rat_v.size() == 0) {
            send_error(res, 400u, &string("missing query params: concept_id, course_id, rating"))
            return
        }
        var concept_id = sv_to_string(&raw cid_v)
        var course_id = sv_to_string(&raw crsid_v)
        var rating_str = sv_to_string(&raw rat_v)
        var learner_id = string("demo")

        var rating : int = 3
        if(rating_str.equals(string("again")) || rating_str.equals(string("1"))) { rating = 1 }
        if(rating_str.equals(string("hard")) || rating_str.equals(string("2"))) { rating = 2 }
        if(rating_str.equals(string("good")) || rating_str.equals(string("3"))) { rating = 3 }
        if(rating_str.equals(string("easy")) || rating_str.equals(string("4"))) { rating = 4 }

        var state = underlayer_repository::get_concept_state(&raw db, &learner_id, &concept_id, &course_id)
        state.learner_id = learner_id.copy()
        state.concept_id = concept_id.copy()
        state.course_id = course_id.copy()

        var params = underlayer_learning::init_fsrs_params()
        var rs = ReviewState::make()
        rs.difficulty = state.difficulty_rating
        if(rs.difficulty < 1.0) { rs.difficulty = 5.0 }
        if(rs.difficulty > 10.0) { rs.difficulty = 5.0 }
        rs.stability = 1.0
        rs.reps = state.attempts
        rs.lapses = state.attempts - state.correct
        rs.elapsed_days = 0
        rs.scheduled_days = state.next_review - state.last_studied
        if(rs.scheduled_days < 0) { rs.scheduled_days = 0 }

        var new_rs = underlayer_learning::fsrs_update_state(&params, &rs, rating)

        state.attempts = state.attempts + 1
        if(rating >= 3) { state.correct = state.correct + 1 }
        if(rating >= 3) { state.streak = state.streak + 1 } else { state.streak = 0 }
        state.last_studied = underlayer_core::current_timestamp()
        state.next_review = state.last_studied + new_rs.scheduled_days
        state.difficulty_rating = new_rs.difficulty

        if(new_rs.reps == 1) { state.status = string("learning") }
        else if(new_rs.lapses > 0) { state.status = string("reviewing") }
        else if(new_rs.reps >= 5 && state.streak >= 3) { state.status = string("mastered") }
        else { state.status = string("reviewing") }

        underlayer_repository::upsert_concept_state(&raw db, &raw state)

        // Record session item if session_id provided (1.2.6, 1.2.7)
        if(sid_v.size() > 0) {
            var session_id = sv_to_string(&raw sid_v)
            var time_spent : i64 = 0
            if(time_v.size() > 0) {
                time_spent = underlayer_repository::parse_i64(time_v)
            }
            underlayer_repository::record_session_item(&raw db, &session_id, &concept_id, rating, time_spent)
        }

        var resp = string("{\"status\":\"ok\",\"rating\":")
        var rating_out = underlayer_core::int_to_string(rating as i64)
        resp.append_string(&rating_out)
        resp.append_view(",\"next_interval\":")
        var interval_out = underlayer_core::int_to_string(new_rs.scheduled_days)
        resp.append_string(&interval_out)
        resp.append_view(",\"streak\":")
        var streak_out = underlayer_core::int_to_string(state.streak as i64)
        resp.append_string(&streak_out)
        resp.append_view(",\"new_status\":\"")
        resp.append_string(&state.status)
        resp.append_view("\"")
        // 1.1.15: Include ease_factor in response
        resp.append_view(",\"ease_factor\":")
        var ef_out = underlayer_learning::f64_to_string(new_rs.ease_factor)
        resp.append_string(&ef_out)
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

    public func handle_review_end(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        underlayer_repository::finish_session(&raw db, &raw session_id, 0, 0)

        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    public func handle_review_due(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")
        var limit : int = 10

        var due_items = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, limit)
        var body = std::string("{\"items\":[")
        var i : size_t = 0
        while(i < due_items.size()) {
            if(i > 0) { body.append_view(",") }
            var item = due_items.get_ptr(i)
            body.append_view("{\"id\":\"")
            body.append_string(&item.id)
            body.append_view("\",\"concept\":\"")
            body.append_string(&item.concept_id)
            body.append_view("\",\"type\":\"")
            body.append_string(&item.item_type)
            body.append_view("\",\"front\":\"")
            body.append_string(&item.front)
            body.append_view("\",\"back\":\"")
            body.append_string(&item.back)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("],\"total\":")
        var total_str = underlayer_core::int_to_string(due_items.size() as i64)
        body.append_string(&total_str)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // ---- Session History (1.2.21, 1.2.22) ----
    public func handle_session_history(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var sessions = underlayer_repository::get_learner_sessions(&raw db, &learner_id, 20)

        var body = std::string("{\"sessions\":[")
        var i : size_t = 0
        while(i < sessions.size()) {
            if(i > 0) { body.append_view(",") }
            var s = sessions.get_ptr(i)
            body.append_view("{\"id\":\"")
            body.append_string(&s.id)
            body.append_view("\",\"start_time\":")
            var st_str = underlayer_core::int_to_string(s.start_time)
            body.append_string(&st_str)
            body.append_view(",\"end_time\":")
            var et_str = underlayer_core::int_to_string(s.end_time)
            body.append_string(&et_str)
            body.append_view(",\"type\":\"")
            body.append_string(&s.session_type)
            body.append_view("\",\"attempted\":")
            var ea_str = underlayer_core::int_to_string(s.exercises_attempted as i64)
            body.append_string(&ea_str)
            body.append_view(",\"correct\":")
            var ec_str = underlayer_core::int_to_string(s.exercises_correct as i64)
            body.append_string(&ec_str)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // ---- Session Detail (1.2.22) ----
    public func handle_session_detail(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            var path = req.path.to_view()
            var segments = underlayer_core::path_segments(&path)
            if(segments.size() >= 2) {
                sid_v = *segments.get_ptr(segments.size() - 1)
            }
        }
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing session_id param or path segment"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)

        var items = underlayer_repository::get_session_items(&raw db, &session_id)
        var stats = underlayer_repository::get_session_stats(&raw db, &session_id)

        var body = std::string("{\"session_id\":\"")
        body.append_string(&session_id)
        body.append_view("\",\"stats\":{\"total\":")
        var t_str = underlayer_core::int_to_string(stats.total_items as i64)
        body.append_string(&t_str)
        body.append_view(",\"correct\":")
        var c_str = underlayer_core::int_to_string(stats.correct_items as i64)
        body.append_string(&c_str)
        body.append_view(",\"time_ms\":")
        var tm_str = underlayer_core::int_to_string(stats.total_time_ms)
        body.append_string(&tm_str)
        body.append_view("},\"items\":[")
        var i : size_t = 0
        while(i < items.size()) {
            if(i > 0) { body.append_view(",") }
            var item = items.get_ptr(i)
            body.append_view("{\"concept\":\"")
            body.append_string(&item.concept_id)
            body.append_view("\",\"rating\":")
            var r_str = underlayer_core::int_to_string(item.rating as i64)
            body.append_string(&r_str)
            body.append_view(",\"time_ms\":")
            var it_str = underlayer_core::int_to_string(item.time_spent_ms)
            body.append_string(&it_str)
            body.append_view(",\"at\":")
            var a_str = underlayer_core::int_to_string(item.reviewed_at)
            body.append_string(&a_str)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // ---- Session Pause (1.2.9) ----
    public func handle_session_pause(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        underlayer_repository::pause_session(&raw db, &raw session_id)
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"state\":\"paused\"}")
        send_json_str(res, &raw resp)
    }

    // ---- Session Resume (1.2.10) ----
    public func handle_session_resume(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        underlayer_repository::resume_session(&raw db, &raw session_id)
        // Return items already reviewed so client can rebuild state
        var items = underlayer_repository::get_session_items(&raw db, &session_id)
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"state\":\"active\",\"reviewed\":")
        var t_str = underlayer_core::int_to_string(items.size() as i64)
        resp.append_string(&t_str)
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

    // ---- Session Abort (1.2.11) ----
    public func handle_session_abort(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        underlayer_repository::abort_session(&raw db, &raw session_id)
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"state\":\"aborted\"}")
        send_json_str(res, &raw resp)
    }

    // ---- Session Undo (1.2.12) ----
    public func handle_session_undo(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        var undone = underlayer_repository::undo_last_item(&raw db, &raw session_id)
        if(!undone) {
            send_error(res, 404u, &string("no items to undo"))
            return
        }
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"undone\":true}")
        send_json_str(res, &raw resp)
    }

    // ---- Session Skip (1.2.13) ----
    public func handle_session_skip(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var q_cid = string("concept_id")
        var sid_v = req.query.get(&q_sid.to_view())
        var cid_v = req.query.get(&q_cid.to_view())
        if(sid_v.size() == 0 || cid_v.size() == 0) {
            send_error(res, 400u, &string("missing query params: session_id, concept_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        var concept_id = sv_to_string(&raw cid_v)
        underlayer_repository::skip_item(&raw db, &raw session_id, &raw concept_id)
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"skipped\":\"")
        resp.append_string(&concept_id)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

}
