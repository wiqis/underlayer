// underlayer_web — Analytics page handlers (HTML + JSON API).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // GET /analytics — HTML analytics dashboard
    public func handle_analytics_page(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var html_out = render_analytics_page(db, &learner_id)
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

    // GET /analytics/:courseId — HTML course-specific analytics
    public func handle_course_analytics_page(db : *DbClient, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var html_out = render_course_analytics_page(db, course_id, &learner_id)
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

    // GET /api/analytics/overview — JSON overview stats
    public func handle_analytics_overview_api(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var course_id = string("elf")

        var states = underlayer_repository::get_all_concept_states(db, &learner_id, &course_id)
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var sessions = underlayer_repository::get_learner_sessions(db, &learner_id, 1000)

        // Compute accuracy
        var total_items : int = 0
        var total_correct : int = 0
        var si : size_t = 0
        while(si < sessions.size()) {
            var s = sessions.get_ptr(si)
            total_items = total_items + s.exercises_attempted
            total_correct = total_correct + s.exercises_correct
            si = si + 1
        }
        var accuracy : f64 = 0.0
        if(total_items > 0) { accuracy = (total_correct as f64) / (total_items as f64) }

        // Compute streak (consecutive days with sessions)
        var streak : i64 = 0
        if(sessions.size() > 0) {
            var now = underlayer_core::current_timestamp()
            var day_seconds : i64 = 86400
            var current_day = now / day_seconds
            var streak_day = current_day
            var found_today = false
            var si2 : size_t = 0
            while(si2 < sessions.size()) {
                var s2 = sessions.get_ptr(si2)
                var session_day = s2.start_time / day_seconds
                if(session_day == current_day) { found_today = true }
                si2 = si2 + 1
            }
            if(!found_today) {
                // Check if yesterday had sessions
                var yesterday = current_day - 1
                var found_yesterday = false
                var si3 : size_t = 0
                while(si3 < sessions.size()) {
                    var s3 = sessions.get_ptr(si3)
                    var session_day = s3.start_time / day_seconds
                    if(session_day == yesterday) { found_yesterday = true }
                    si3 = si3 + 1
                }
                if(found_yesterday) { streak = 1 }
                else { streak = 0 }
            } else {
                streak = 1
                // Count backwards from yesterday
                var check_day = current_day - 1
                var max_check : i64 = 365
                var ci : i64 = 0
                while(ci < max_check) {
                    var found = false
                    var si4 : size_t = 0
                    while(si4 < sessions.size()) {
                        var s4 = sessions.get_ptr(si4)
                        var session_day = s4.start_time / day_seconds
                        if(session_day == check_day) { found = true }
                        si4 = si4 + 1
                    }
                    if(found) { streak = streak + 1 }
                    else { ci = max_check }
                    check_day = check_day - 1
                    ci = ci + 1
                }
            }
        }

        // Build JSON
        var body = string("{\"total_concepts_mastered\":")
        var m_out = underlayer_core::int_to_string(health.mastered as i64)
        body.append_string(&m_out)
        body.append_view(",\"total_concepts\":")
        var t_out = underlayer_core::int_to_string(health.total_concepts as i64)
        body.append_string(&t_out)
        body.append_view(",\"accuracy\":")
        var a_out = underlayer_learning::f64_to_string(accuracy)
        body.append_string(&a_out)
        body.append_view(",\"total_sessions\":")
        var s_out = underlayer_core::int_to_string(sessions.size() as i64)
        body.append_string(&s_out)
        body.append_view(",\"streak\":")
        var st_out = underlayer_core::int_to_string(streak)
        body.append_string(&st_out)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

}
