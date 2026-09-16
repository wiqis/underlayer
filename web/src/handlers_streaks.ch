// underlayer_web — Streaks API handlers.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_get_streak(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var streak = underlayer_repository::get_streak(db, &learner_id)
        var body = std::string("{\"learner_id\":\"")
        body.append_string(&streak.learner_id)
        body.append_view("\",\"current_streak\":")
        var cs_str = underlayer_core::int_to_string(streak.current_streak as i64)
        body.append_view(cs_str.to_view())
        body.append_view(",\"longest_streak\":")
        var ls_str = underlayer_core::int_to_string(streak.longest_streak as i64)
        body.append_view(ls_str.to_view())
        body.append_view(",\"total_active_days\":")
        var tad_str = underlayer_core::int_to_string(streak.total_active_days as i64)
        body.append_view(tad_str.to_view())
        body.append_view(",\"last_active_date\":\"")
        body.append_string(&streak.last_active_date)
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

    public func handle_record_activity(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var streak = underlayer_repository::record_activity(db, &learner_id)
        var body = std::string("{\"learner_id\":\"")
        body.append_string(&streak.learner_id)
        body.append_view("\",\"current_streak\":")
        var cs_str = underlayer_core::int_to_string(streak.current_streak as i64)
        body.append_view(cs_str.to_view())
        body.append_view(",\"longest_streak\":")
        var ls_str = underlayer_core::int_to_string(streak.longest_streak as i64)
        body.append_view(ls_str.to_view())
        body.append_view(",\"total_active_days\":")
        var tad_str = underlayer_core::int_to_string(streak.total_active_days as i64)
        body.append_view(tad_str.to_view())
        body.append_view(",\"last_active_date\":\"")
        body.append_string(&streak.last_active_date)
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

    public func handle_weekly_activity(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var days = underlayer_repository::get_weekly_activity(db, &learner_id)
        var body = std::string("{\"learner_id\":\"")
        body.append_view(learner_id.to_view())
        body.append_view("\",\"days\":[")
        var i : size_t = 0
        while(i < days.size()) {
            if(i > 0) { body.append_view(",") }
            var d = days.get_ptr(i)
            body.append_view("{\"date\":\"")
            body.append_string(&d.date)
            body.append_view("\",\"active\":")
            if(d.active) { body.append_view("true") } else { body.append_view("false") }
            body.append_view(",\"sessions\":")
            var sess_str = underlayer_core::int_to_string(d.sessions as i64)
            body.append_view(sess_str.to_view())
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

}