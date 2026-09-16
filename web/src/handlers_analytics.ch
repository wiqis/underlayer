// underlayer_web — Learning analytics handlers (6.2.3, 6.2.8-9, 6.2.13-14).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // 6.2.3: Course completion + velocity
    public func handle_course_analytics(db : &DbClient, course_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var cid = sv_to_string(course_id)
        var sql = string("SELECT total_concepts, mastered_concepts, learning_concepts, completion_pct, velocity_concepts_per_week, total_time_seconds, updated_at FROM course_analytics WHERE learner_id = '")
        sql.append_string(&learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(&cid)
        sql.append_view("'")
        var result = underlayer_db::query_sql(&raw db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            var body = string("{\"course_id\":\"")
            body.append_string(&cid)
            body.append_view("\",\"total_concepts\":")
            var _av0 = row.vals.get_ptr(0).copy()
            body.append_string(&_av0)
            body.append_view(",\"mastered_concepts\":")
            var _av1 = row.vals.get_ptr(1).copy()
            body.append_string(&_av1)
            body.append_view(",\"learning_concepts\":")
            var _av2 = row.vals.get_ptr(2).copy()
            body.append_string(&_av2)
            body.append_view(",\"completion_pct\":")
            var _av3 = row.vals.get_ptr(3).copy()
            body.append_string(&_av3)
            body.append_view(",\"velocity_concepts_per_week\":")
            var _av4 = row.vals.get_ptr(4).copy()
            body.append_string(&_av4)
            body.append_view(",\"total_time_seconds\":")
            var _av5 = row.vals.get_ptr(5).copy()
            body.append_string(&_av5)
            body.append_view(",\"updated_at\":")
            var _av6 = row.vals.get_ptr(6).copy()
            body.append_string(&_av6)
            body.append_view("}")
            send_json_str(res, &raw body)
        } else {
            var body = string("{\"course_id\":\"")
            body.append_string(&cid)
            body.append_view("\",\"total_concepts\":0,\"mastered_concepts\":0,\"learning_concepts\":0,\"completion_pct\":0,\"velocity_concepts_per_week\":0,\"total_time_seconds\":0}")
            send_json_str(res, &raw body)
        }
    }

    // 6.2.8: Difficulty distribution across concepts
    public func handle_difficulty_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var sql = string("SELECT concept_id, avg_rating, rating_count, easy_count, medium_count, hard_count FROM difficulty_analytics WHERE learner_id = '")
        sql.append_string(&learner_id)
        sql.append_view("' ORDER BY rating_count DESC")
        var result = underlayer_db::query_sql(&raw db, &raw sql)
        var body = string("{\"items\":[")
        var i : size_t = 0
        while(i < result.rows.size()) {
            if(i > 0) { body.append_view(",") }
            var row = result.rows.get_ptr(i)
            body.append_view("{\"concept_id\":\"")
            var _av0 = row.vals.get_ptr(0).copy()
            body.append_string(&_av0)
            body.append_view("\",\"avg_rating\":")
            var _av1 = row.vals.get_ptr(1).copy()
            body.append_string(&_av1)
            body.append_view(",\"rating_count\":")
            var _av2 = row.vals.get_ptr(2).copy()
            body.append_string(&_av2)
            body.append_view(",\"easy_count\":")
            var _av3 = row.vals.get_ptr(3).copy()
            body.append_string(&_av3)
            body.append_view(",\"medium_count\":")
            var _av4 = row.vals.get_ptr(4).copy()
            body.append_string(&_av4)
            body.append_view(",\"hard_count\":")
            var _av5 = row.vals.get_ptr(5).copy()
            body.append_string(&_av5)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // 6.2.9: Most common mistakes
    public func handle_error_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var sql = string("SELECT concept_id, exercise_id, error_count, last_error_at, last_error_text FROM error_analytics WHERE learner_id = '")
        sql.append_string(&learner_id)
        sql.append_view("' ORDER BY error_count DESC LIMIT 20")
        var result = underlayer_db::query_sql(&raw db, &raw sql)
        var body = string("{\"errors\":[")
        var i : size_t = 0
        while(i < result.rows.size()) {
            if(i > 0) { body.append_view(",") }
            var row = result.rows.get_ptr(i)
            body.append_view("{\"concept_id\":\"")
            var _av0 = row.vals.get_ptr(0).copy()
            body.append_string(&_av0)
            body.append_view("\",\"exercise_id\":\"")
            var _av1 = row.vals.get_ptr(1).copy()
            body.append_string(&_av1)
            body.append_view("\",\"error_count\":")
            var _av2 = row.vals.get_ptr(2).copy()
            body.append_string(&_av2)
            body.append_view(",\"last_error_at\":")
            var _av3 = row.vals.get_ptr(3).copy()
            body.append_string(&_av3)
            body.append_view(",\"last_error_text\":\"")
            var _av4 = row.vals.get_ptr(4).copy()
            body.append_string(&_av4)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // 6.2.13: Sessions per week over last 12 weeks
    public func handle_engagement_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var now = underlayer_core::current_timestamp()
        var twelve_weeks = 12 * 7 * 24 * 3600
        var since = now - twelve_weeks as i64
        var sql = string("SELECT week_start, sessions_count, total_time_seconds, concepts_studied, exercises_attempted, exercises_correct FROM engagement_analytics WHERE learner_id = '")
        sql.append_string(&learner_id)
        sql.append_view("' AND week_start >= ")
        var since_str = underlayer_core::int_to_string(since)
        sql.append_view(since_str.to_view())
        sql.append_view(" ORDER BY week_start ASC")
        var result = underlayer_db::query_sql(&raw db, &raw sql)
        var body = string("{\"weeks\":[")
        var i : size_t = 0
        while(i < result.rows.size()) {
            if(i > 0) { body.append_view(",") }
            var row = result.rows.get_ptr(i)
            body.append_view("{\"week_start\":")
            var _av0 = row.vals.get_ptr(0).copy()
            body.append_string(&_av0)
            body.append_view(",\"sessions_count\":")
            var _av1 = row.vals.get_ptr(1).copy()
            body.append_string(&_av1)
            body.append_view(",\"total_time_seconds\":")
            var _av2 = row.vals.get_ptr(2).copy()
            body.append_string(&_av2)
            body.append_view(",\"concepts_studied\":")
            var _av3 = row.vals.get_ptr(3).copy()
            body.append_string(&_av3)
            body.append_view(",\"exercises_attempted\":")
            var _av4 = row.vals.get_ptr(4).copy()
            body.append_string(&_av4)
            body.append_view(",\"exercises_correct\":")
            var _av5 = row.vals.get_ptr(5).copy()
            body.append_string(&_av5)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // 6.2.14: Concepts completed per week
    public func handle_velocity_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var now = underlayer_core::current_timestamp()
        var twelve_weeks = 12 * 7 * 24 * 3600
        var since = now - twelve_weeks as i64
        var sql = string("SELECT week_start, concepts_completed, items_reviewed, accuracy_pct, streak_days FROM velocity_analytics WHERE learner_id = '")
        sql.append_string(&learner_id)
        sql.append_view("' AND week_start >= ")
        var since_str = underlayer_core::int_to_string(since)
        sql.append_view(since_str.to_view())
        sql.append_view(" ORDER BY week_start ASC")
        var result = underlayer_db::query_sql(&raw db, &raw sql)
        var body = string("{\"weeks\":[")
        var i : size_t = 0
        while(i < result.rows.size()) {
            if(i > 0) { body.append_view(",") }
            var row = result.rows.get_ptr(i)
            body.append_view("{\"week_start\":")
            var _av0 = row.vals.get_ptr(0).copy()
            body.append_string(&_av0)
            body.append_view(",\"concepts_completed\":")
            var _av1 = row.vals.get_ptr(1).copy()
            body.append_string(&_av1)
            body.append_view(",\"items_reviewed\":")
            var _av2 = row.vals.get_ptr(2).copy()
            body.append_string(&_av2)
            body.append_view(",\"accuracy_pct\":")
            var _av3 = row.vals.get_ptr(3).copy()
            body.append_string(&_av3)
            body.append_view(",\"streak_days\":")
            var _av4 = row.vals.get_ptr(4).copy()
            body.append_string(&_av4)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

}
