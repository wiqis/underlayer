// underlayer_repository — Session item tracking CRUD.
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_models::Session

public namespace underlayer_repository {

    public struct SessionItem {
        var session_id : string
        var concept_id : string
        var rating : int
        var time_spent_ms : i64
        var reviewed_at : i64

        @make
        func make() : SessionItem {
            return SessionItem {
                session_id = string(),
                concept_id = string(),
                rating = 0,
                time_spent_ms = 0,
                reviewed_at = 0
            }
        }
    }

    public func record_session_item(db : *DbClient, session_id : &string, concept_id : &string, rating : int, time_spent_ms : i64) {
        var now = underlayer_core::current_timestamp()
        var sql = string("INSERT INTO session_items (session_id, concept_id, rating, time_spent_ms, reviewed_at) VALUES ('")
        sql.append_string(session_id)
        sql.append_view("', '")
        sql.append_string(concept_id)
        sql.append_view("', ")
        var r_str = underlayer_core::int_to_string(rating as i64)
        sql.append_view(r_str.to_view())
        sql.append_view(", ")
        var t_str = underlayer_core::int_to_string(time_spent_ms)
        sql.append_view(t_str.to_view())
        sql.append_view(", ")
        var a_str = underlayer_core::int_to_string(now)
        sql.append_view(a_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_session_items(db : *DbClient, session_id : &string) : vector<SessionItem> {
        var items = vector<SessionItem>()
        var sql = string("SELECT concept_id, rating, time_spent_ms, reviewed_at FROM session_items WHERE session_id = '")
        sql.append_string(session_id)
        sql.append_view("' ORDER BY reviewed_at ASC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 4) {
                var item = SessionItem::make()
                item.session_id = session_id.copy()
                item.concept_id = row.vals.get_ptr(0).copy()
                item.rating = parse_i64(row.vals.get_ptr(1).to_view()) as int
                item.time_spent_ms = parse_i64(row.vals.get_ptr(2).to_view())
                item.reviewed_at = parse_i64(row.vals.get_ptr(3).to_view())
                items.push(item)
            }
            ri = ri + 1
        }
        return items
    }

    public func get_session_stats(db : *DbClient, session_id : &string) : SessionStats {
        var stats = SessionStats::make()
        var sql = string("SELECT COUNT(*), SUM(CASE WHEN rating >= 3 THEN 1 ELSE 0 END), SUM(time_spent_ms) FROM session_items WHERE session_id = '")
        sql.append_string(session_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 3) {
                stats.total_items = parse_i64(row.vals.get_ptr(0).to_view()) as int
                stats.correct_items = parse_i64(row.vals.get_ptr(1).to_view()) as int
                stats.total_time_ms = parse_i64(row.vals.get_ptr(2).to_view())
            }
        }
        return stats
    }

    public struct SessionStats {
        var total_items : int
        var correct_items : int
        var total_time_ms : i64

        @make
        func make() : SessionStats {
            return SessionStats {
                total_items = 0,
                correct_items = 0,
                total_time_ms = 0
            }
        }
    }

    public func get_learner_sessions(db : *DbClient, learner_id : &string, limit : int) : vector<Session> {
        var sessions = vector<Session>()
        var sql = string("SELECT id, start_time, end_time, type, exercises_attempted, exercises_correct FROM sessions WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' ORDER BY start_time DESC LIMIT ")
        var lim_str = underlayer_core::int_to_string(limit as i64)
        sql.append_view(lim_str.to_view())
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 6) {
                var s = underlayer_models::Session::make()
                s.id = row.vals.get_ptr(0).copy()
                s.learner_id = learner_id.copy()
                s.start_time = parse_i64(row.vals.get_ptr(1).to_view())
                s.end_time = parse_i64(row.vals.get_ptr(2).to_view())
                s.session_type = row.vals.get_ptr(3).copy()
                s.exercises_attempted = parse_i64(row.vals.get_ptr(4).to_view()) as int
                s.exercises_correct = parse_i64(row.vals.get_ptr(5).to_view()) as int
                sessions.push(s)
            }
            ri = ri + 1
        }
        return sessions
    }

}
