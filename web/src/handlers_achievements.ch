// underlayer_web — Achievement API handlers.
using std::string
using underlayer_db::DbClient

public namespace underlayer_web {

    // GET /api/achievements — Get all earned achievements for current user
    public func handle_get_achievements(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var achs = underlayer_repository::get_achievements(db, &learner_id)
        var resp = string("[")
        var i : size_t = 0
        while(i < achs.size()) {
            if(i > 0) { resp.append_view(",") }
            var a = achs.get_ptr(i)
            resp.append_view("{\"id\":\"")
            resp.append_string(&a.id)
            resp.append_view("\",\"badge_type\":\"")
            resp.append_string(&a.badge_type)
            resp.append_view("\",\"badge_name\":\"")
            resp.append_string(&a.badge_name)
            resp.append_view("\",\"description\":\"")
            resp.append_string(&a.description)
            resp.append_view("\",\"icon\":\"")
            resp.append_string(&a.icon)
            resp.append_view("\",\"earned_at\":")
            var ts_str = underlayer_core::int_to_string(a.earned_at)
            resp.append_view(ts_str.to_view())
            resp.append_view("}")
            i = i + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

    // POST /api/achievements/check — Trigger achievement checks
    public func handle_check_achievements(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        // Count mastered concepts and total exercises
        var mastered_count = 0
        var exercise_count = 0

        // Count exercises via sessions
        var sess_sql = string("SELECT COALESCE(SUM(exercises_attempted), 0) FROM sessions WHERE learner_id = '")
        sess_sql.append_view(learner_id.to_view())
        sess_sql.append_view("'")
        var sess_result = underlayer_db::query_sql(db, &raw sess_sql)
        if(sess_result.rows.size() > 0) {
            var row = sess_result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                exercise_count = parse_int(row.vals.get_ptr(0).to_view())
            }
        }

        // Count mastered concepts
        var cs_sql = string("SELECT COUNT(*) FROM concept_states WHERE learner_id = '")
        cs_sql.append_view(learner_id.to_view())
        cs_sql.append_view("' AND status = 'mastered'")
        var cs_result = underlayer_db::query_sql(db, &raw cs_sql)
        if(cs_result.rows.size() > 0) {
            var row = cs_result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                mastered_count = parse_int(row.vals.get_ptr(0).to_view())
            }
        }

        // Count consecutive days studied
        var streak_days = 0
        var streak_sql = string("SELECT DISTINCT DATE(start_time, 'unixepoch') as day FROM sessions WHERE learner_id = '")
        streak_sql.append_view(learner_id.to_view())
        streak_sql.append_view("' ORDER BY day DESC LIMIT 100")
        var streak_result = underlayer_db::query_sql(db, &raw streak_sql)
        var now = underlayer_core::current_timestamp()
        var day_secs : i64 = 86400
        var expected_day = now / day_secs
        var ri : size_t = 0
        while(ri < streak_result.rows.size()) {
            var row = streak_result.rows.get_ptr(ri)
            if(row.vals.size() > 0) {
                var day_str = row.vals.get_ptr(0).copy()
                var day_val = underlayer_repository::parse_i64(day_str.to_view())
                if(day_val == expected_day) {
                    streak_days = streak_days + 1
                    expected_day = expected_day - 1
                } else {
                    break
                }
            }
            ri = ri + 1
        }

        underlayer_repository::check_and_award_streak(db, &learner_id, streak_days)
        underlayer_repository::check_and_award_milestones(db, &learner_id, mastered_count, exercise_count)

        var count = underlayer_repository::get_achievement_count(db, &learner_id)
        var resp = string("{\"ok\":true,\"count\":")
        var count_str = underlayer_core::int_to_string(count)
        resp.append_view(count_str.to_view())
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

    // GET /api/achievements/count — Get count of earned achievements
    public func handle_achievement_count(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var count = underlayer_repository::get_achievement_count(db, &learner_id)
        var resp = string("{\"count\":")
        var count_str = underlayer_core::int_to_string(count)
        resp.append_view(count_str.to_view())
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

}
