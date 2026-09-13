// underlayer_web — Progress and course progress handlers (6.1.1-6.1.5).
using std::string
using std::string_view
using underlayer_db::DbClient
using underlayer_repository::parse_i64

public namespace underlayer_web {

    public func handle_course_progress(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        var course_id_raw = string("elf")
        if(segments.size() >= 4) {
            var sv = segments.get_ptr(3)
            var i : size_t = 0
            while(i < sv.size()) { course_id_raw.append(sv.get(i)); i = i + 1 }
        }
        var learner_id = string("demo")
        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id_raw)
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var body = std::string("{\"course_id\":\"")
        body.append_string(&course_id_raw)
        body.append_view("\",\"health\":")
        var health_str = underlayer_core::int_to_string((health.health_score * 100.0) as i64)
        body.append_string(&health_str)
        body.append_view(",\"mastered\":")
        var mastered_str = underlayer_core::int_to_string(health.mastered as i64)
        body.append_string(&mastered_str)
        body.append_view(",\"learning\":")
        var learning_str = underlayer_core::int_to_string(health.learning as i64)
        body.append_string(&learning_str)
        body.append_view(",\"reviewing\":")
        var reviewing_str = underlayer_core::int_to_string(health.reviewing as i64)
        body.append_string(&reviewing_str)
        body.append_view(",\"unlearned\":")
        var unlearned_str = underlayer_core::int_to_string(health.unlearned as i64)
        body.append_string(&unlearned_str)
        body.append_view(",\"concepts\":[")
        var ci : size_t = 0
        while(ci < states.size()) {
            if(ci > 0) { body.append_view(",") }
            var s = states.get_ptr(ci)
            body.append_view("{\"concept_id\":\"")
            body.append_string(&s.concept_id)
            body.append_view("\",\"status\":\"")
            body.append_string(&s.status)
            body.append_view("\",\"attempts\":")
            var a_str = underlayer_core::int_to_string(s.attempts as i64)
            body.append_string(&a_str)
            body.append_view(",\"correct\":")
            var c_str = underlayer_core::int_to_string(s.correct as i64)
            body.append_string(&c_str)
            body.append_view("}")
            ci = ci + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    public func handle_progress(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")

        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
        var health = underlayer_learning::compute_knowledge_health(&raw states)

        var body = std::string("{\"learner_id\":\"")
        body.append_string(&learner_id)
        body.append_view("\",\"course_id\":\"")
        body.append_string(&course_id)
        body.append_view("\",\"health\":")
        var health_str = underlayer_core::int_to_string((health.health_score * 100.0) as i64)
        body.append_string(&health_str)
        // 6.1.3: Progress percentage
        body.append_view(",\"progress_percentage\":")
        body.append_string(&health_str)
        body.append_view(",\"mastered\":")
        var mastered_str = underlayer_core::int_to_string(health.mastered as i64)
        body.append_string(&mastered_str)
        body.append_view(",\"learning\":")
        var learning_str = underlayer_core::int_to_string(health.learning as i64)
        body.append_string(&learning_str)
        body.append_view(",\"reviewing\":")
        var reviewing_str = underlayer_core::int_to_string(health.reviewing as i64)
        body.append_string(&reviewing_str)
        body.append_view(",\"unlearned\":")
        var unlearned_str = underlayer_core::int_to_string(health.unlearned as i64)
        body.append_string(&unlearned_str)
        // 6.1.4: Milestones (25%, 50%, 75%, 100%)
        var pct = (health.health_score * 100.0) as i64
        body.append_view(",\"milestones\":{\"reached\":[")
        var first = true
        if(pct >= 25) {
            if(!first) { body.append_view(",") }
            body.append_view("25")
            first = false
        }
        if(pct >= 50) {
            if(!first) { body.append_view(",") }
            body.append_view("50")
            first = false
        }
        if(pct >= 75) {
            if(!first) { body.append_view(",") }
            body.append_view("75")
            first = false
        }
        if(pct >= 100) {
            if(!first) { body.append_view(",") }
            body.append_view("100")
            first = false
        }
        body.append_view("],\"next_milestone\":")
        if(pct < 25) { body.append_view("25") }
        else if(pct < 50) { body.append_view("50") }
        else if(pct < 75) { body.append_view("75") }
        else if(pct < 100) { body.append_view("100") }
        else { body.append_view("null") }
        body.append_view("}")
        // 6.1.5: Goal
        var goal_result = underlayer_repository::get_learning_goal(&raw db, &learner_id, &course_id)
        body.append_view(",\"goal\":")
        if(goal_result.found) {
            body.append_view("{\"target_date\":")
            var td_str = underlayer_core::int_to_string(goal_result.target_date)
            body.append_string(&td_str)
            body.append_view("}")
        } else {
            body.append_view("null")
        }
        // 6.1.9: Progress comparison (anonymous, vs average)
        body.append_view(",\"comparison\":{\"vs_average\":")
        var avg_score : f64 = 0.3  // Assume average is 30%
        var comparison = underlayer_learning::compute_health_comparison(&raw health, avg_score)
        body.append_view("{\"user_score\":")
        var user_out = underlayer_learning::f64_to_string(comparison.user_score)
        body.append_string(&user_out)
        body.append_view(",\"average_score\":")
        var avg_out = underlayer_learning::f64_to_string(comparison.average_score)
        body.append_string(&avg_out)
        body.append_view(",\"percentile\":")
        var pct_out = underlayer_core::int_to_string(comparison.percentile as i64)
        body.append_string(&pct_out)
        body.append_view("}}")
        // 6.1.10: Progress prediction (estimated completion date)
        body.append_view(",\"prediction\":")
        if(health.mastered > 0 && health.total_concepts > health.mastered) {
            // Simple prediction: if mastered N concepts in last week, predict remaining
            var remaining = health.total_concepts - health.mastered
            var est_days = remaining * 7  // Rough estimate: 1 concept per day
            body.append_view("{\"estimated_days\":")
            var est_out = underlayer_core::int_to_string(est_days as i64)
            body.append_string(&est_out)
            body.append_view(",\"confidence\":\"low\"}")
        } else {
            body.append_view("null")
        }
        body.append_view(",\"concepts\":[")

        var i : size_t = 0
        while(i < states.size()) {
            if(i > 0) { body.append_view(",") }
            var s = states.get_ptr(i)
            body.append_view("{\"concept_id\":\"")
            body.append_string(&s.concept_id)
            body.append_view("\",\"status\":\"")
            body.append_string(&s.status)
            body.append_view("\",\"attempts\":")
            var attempts_str = underlayer_core::int_to_string(s.attempts as i64)
            body.append_string(&attempts_str)
            body.append_view(",\"correct\":")
            var correct_str = underlayer_core::int_to_string(s.correct as i64)
            body.append_string(&correct_str)
            body.append_view(",\"streak\":")
            var streak_str = underlayer_core::int_to_string(s.streak as i64)
            body.append_string(&streak_str)
            body.append_view("}")
            i = i + 1
        }

        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // 6.1.5: Set learning goal
    public func handle_set_goal(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var q_td = string("target_date")
        var td_v = req.query.get(&q_td.to_view())
        if(td_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: target_date"))
            return
        }
        var target_date = parse_i64(td_v) as i64
        var learner_id = string("demo")
        var course_id = string("elf")
        underlayer_repository::set_learning_goal(&raw db, &learner_id, &course_id, target_date)
        var ok_body = string("{\"ok\":true}")
        send_json_str(res, &raw ok_body)
    }

    // 6.1.5: Delete learning goal
    public func handle_delete_goal(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")
        underlayer_repository::delete_learning_goal(&raw db, &learner_id, &course_id)
        var ok_body = string("{\"ok\":true}")
        send_json_str(res, &raw ok_body)
    }

    // 6.1.7: Progress export (JSON)
    public func handle_progress_export(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")
        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
        var sessions = underlayer_repository::get_learner_sessions(&raw db, &learner_id, 100)
        var health = underlayer_learning::compute_knowledge_health(&raw states)

        var body = string("{\"learner_id\":\"")
        body.append_string(&learner_id)
        body.append_view("\",\"course_id\":\"")
        body.append_string(&course_id)
        body.append_view("\",\"exported_at\":")
        var now = underlayer_core::current_timestamp()
        var now_out = underlayer_core::int_to_string(now)
        body.append_string(&now_out)
        body.append_view(",\"health_score\":")
        var hs_out = underlayer_learning::f64_to_string(health.health_score)
        body.append_string(&hs_out)
        body.append_view(",\"mastered\":")
        var m_out = underlayer_core::int_to_string(health.mastered as i64)
        body.append_string(&m_out)
        body.append_view(",\"total_concepts\":")
        var tc_out = underlayer_core::int_to_string(health.total_concepts as i64)
        body.append_string(&tc_out)
        body.append_view(",\"total_sessions\":")
        var ts_out = underlayer_core::int_to_string(sessions.size() as i64)
        body.append_string(&ts_out)
        body.append_view(",\"states\":[")
        var i : size_t = 0
        while(i < states.size()) {
            if(i > 0) { body.append_view(",") }
            var s = states.get_ptr(i)
            body.append_view("{\"concept_id\":\"")
            body.append_string(&s.concept_id)
            body.append_view("\",\"status\":\"")
            body.append_string(&s.status)
            body.append_view("\",\"attempts\":")
            var a_out = underlayer_core::int_to_string(s.attempts as i64)
            body.append_string(&a_out)
            body.append_view(",\"correct\":")
            var c_out = underlayer_core::int_to_string(s.correct as i64)
            body.append_string(&c_out)
            body.append_view(",\"streak\":")
            var st_out = underlayer_core::int_to_string(s.streak as i64)
            body.append_string(&st_out)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // 6.2.1: Session analytics (length, accuracy, time)
    public func handle_session_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")
        var sessions = underlayer_repository::get_learner_sessions(&raw db, &learner_id, 50)
        var total_items : int = 0
        var total_correct : int = 0
        var total_duration_ms : i64 = 0

        var i : size_t = 0
        while(i < sessions.size()) {
            var s = sessions.get_ptr(i)
            total_duration_ms = total_duration_ms + ((s.end_time - s.start_time) * 1000)
            total_correct = total_correct + s.exercises_correct
            total_items = total_items + s.exercises_attempted
            i = i + 1
        }

        var body = string("{\"total_sessions\":")
        var ts_out = underlayer_core::int_to_string(sessions.size() as i64)
        body.append_string(&ts_out)
        body.append_view(",\"total_items\":")
        var ti_out = underlayer_core::int_to_string(total_items as i64)
        body.append_string(&ti_out)
        body.append_view(",\"total_correct\":")
        var tc_out = underlayer_core::int_to_string(total_correct as i64)
        body.append_string(&tc_out)
        body.append_view(",\"accuracy\":")
        if(total_items > 0) {
            var acc = (total_correct as f64) / (total_items as f64)
            var acc_out = underlayer_learning::f64_to_string(acc)
            body.append_string(&acc_out)
        } else {
            body.append_view("0.0")
        }
        body.append_view(",\"total_duration_seconds\":")
        var dur_out = underlayer_core::int_to_string(total_duration_ms / 1000)
        body.append_string(&dur_out)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // 6.2.2: Concept analytics (mastery, time, attempts)
    public func handle_concept_analytics(db : &DbClient, concept_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var cid = sv_to_string(concept_id)
        var course_id = string("elf")
        var state = underlayer_repository::get_concept_state(&raw db, &learner_id, &course_id, &cid)
        var sessions = underlayer_repository::get_learner_sessions(&raw db, &learner_id, 50)

        var total_time_ms : i64 = 0
        var attempts : int = 0
        var correct : int = 0

        var i : size_t = 0
        while(i < sessions.size()) {
            var s = sessions.get_ptr(i)
            var items = underlayer_repository::get_session_items(&raw db, &s.id)
            var j : size_t = 0
            while(j < items.size()) {
                var item = items.get_ptr(j)
                var item_copy = item.concept_id.copy()
                if(item_copy.equals(&cid)) {
                    total_time_ms = total_time_ms + item.time_spent_ms
                    attempts = attempts + 1
                    if(item.rating >= 3) { correct = correct + 1 }
                }
                j = j + 1
            }
            i = i + 1
        }

        var body = string("{\"concept_id\":\"")
        body.append_string(&cid)
        body.append_view("\",\"status\":\"")
        body.append_string(&state.status)
        body.append_view("\",\"attempts\":")
        var att_out = underlayer_core::int_to_string(attempts as i64)
        body.append_string(&att_out)
        body.append_view(",\"correct\":")
        var cor_out = underlayer_core::int_to_string(correct as i64)
        body.append_string(&cor_out)
        body.append_view(",\"accuracy\":")
        if(attempts > 0) {
            var acc = (correct as f64) / (attempts as f64)
            var acc_out = underlayer_learning::f64_to_string(acc)
            body.append_string(&acc_out)
        } else {
            body.append_view("0.0")
        }
        body.append_view(",\"total_time_ms\":")
        var time_out = underlayer_core::int_to_string(total_time_ms)
        body.append_string(&time_out)
        body.append_view(",\"streak\":")
        var streak_out = underlayer_core::int_to_string(state.streak as i64)
        body.append_string(&streak_out)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

}
