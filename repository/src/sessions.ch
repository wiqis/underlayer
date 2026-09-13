// underlayer_repository — Session CRUD + management.
using std::string
using underlayer_db::DbClient
using underlayer_models::Session

public namespace underlayer_repository {

    public func create_session(db : *DbClient, session_id : *string, learner_id : *string, start_time : i64) {
        var sid = session_id.copy()
        var lid = learner_id.copy()
        var sql = string("INSERT OR IGNORE INTO sessions (id, learner_id, start_time, end_time, type, exercises_attempted, exercises_correct, status) VALUES ('")
        sql.append_string(&sid)
        sql.append_view("', '")
        sql.append_string(&lid)
        sql.append_view("', ")
        var st_str = underlayer_core::int_to_string(start_time)
        sql.append_view(st_str.to_view())
        sql.append_view(", 0, 'mixed', 0, 0, 'active')")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func insert_session(db : *DbClient, session : *Session) {
        var sql = string("INSERT OR IGNORE INTO sessions (id, learner_id, start_time, end_time, type, exercises_attempted, exercises_correct, status) VALUES ('")
        sql.append_string(&session.id)
        sql.append_view("', '")
        sql.append_string(&session.learner_id)
        sql.append_view("', ")
        var st_str = underlayer_core::int_to_string(session.start_time)
        sql.append_view(st_str.to_view())
        sql.append_view(", ")
        var et_str = underlayer_core::int_to_string(session.end_time)
        sql.append_view(et_str.to_view())
        sql.append_view(", '")
        sql.append_string(&session.session_type)
        sql.append_view("', ")
        var ea_str = underlayer_core::int_to_string(session.exercises_attempted as i64)
        sql.append_view(ea_str.to_view())
        sql.append_view(", ")
        var ec_str = underlayer_core::int_to_string(session.exercises_correct as i64)
        sql.append_view(ec_str.to_view())
        sql.append_view(", 'active')")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func finish_session(db : *DbClient, session_id : *string, correct : int, total : int) {
        var now = underlayer_core::current_timestamp()
        var sid = session_id.copy()
        var sql = string("UPDATE sessions SET end_time = ")
        var now_str = underlayer_core::int_to_string(now)
        sql.append_view(now_str.to_view())
        sql.append_view(", exercises_attempted = ")
        var total_str = underlayer_core::int_to_string(total as i64)
        sql.append_view(total_str.to_view())
        sql.append_view(", exercises_correct = ")
        var correct_str = underlayer_core::int_to_string(correct as i64)
        sql.append_view(correct_str.to_view())
        sql.append_view(", status = 'completed' WHERE id = '")
        sql.append_string(&sid)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // ---- Session Management (1.2.9-1.2.13) ----

    public func pause_session(db : *DbClient, session_id : *string) {
        var sid = session_id.copy()
        var sql = string("UPDATE sessions SET status = 'paused' WHERE id = '")
        sql.append_string(&sid)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func resume_session(db : *DbClient, session_id : *string) {
        var sid = session_id.copy()
        var sql = string("UPDATE sessions SET status = 'active' WHERE id = '")
        sql.append_string(&sid)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func abort_session(db : *DbClient, session_id : *string) {
        var sid = session_id.copy()
        // Delete session items first
        var del_sql = string("DELETE FROM session_items WHERE session_id = '")
        del_sql.append_string(&sid)
        del_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql)
        // Delete session
        var sql = string("DELETE FROM sessions WHERE id = '")
        sql.append_string(&sid)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func undo_last_item(db : *DbClient, session_id : *string) : bool {
        var sid = session_id.copy()
        // Find the last item
        var sel = string("SELECT id FROM session_items WHERE session_id = '")
        sel.append_string(&sid)
        sel.append_view("' ORDER BY reviewed_at DESC LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sel)
        if(result.rows.size() == 0) { return false }
        var row = result.rows.get_ptr(0)
        var item_id = row.vals.get_ptr(0).copy()
        // Delete it
        var del = string("DELETE FROM session_items WHERE id = '")
        del.append_string(&item_id)
        del.append_view("'")
        underlayer_db::exec_sql(db, &raw del)
        return true
    }

    public func skip_item(db : *DbClient, session_id : *string, concept_id : *string) {
        var now = underlayer_core::current_timestamp()
        var sid = session_id.copy()
        var cid = concept_id.copy()
        var sql = string("INSERT INTO session_items (session_id, concept_id, rating, time_spent_ms, reviewed_at) VALUES ('")
        sql.append_string(&sid)
        sql.append_view("', '")
        sql.append_string(&cid)
        sql.append_view("', 0, 0, ")
        var now_str = underlayer_core::int_to_string(now)
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

}
