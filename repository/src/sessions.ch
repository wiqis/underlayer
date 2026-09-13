// underlayer_repository — Session CRUD.
using std::string
using underlayer_db::DbClient
using underlayer_models::Session

public namespace underlayer_repository {

    public func create_session(db : *DbClient, session_id : *string, learner_id : *string, start_time : i64) {
        var sid = session_id.copy()
        var lid = learner_id.copy()
        var sql = string("INSERT OR IGNORE INTO sessions (id, learner_id, start_time, end_time, type, exercises_attempted, exercises_correct) VALUES ('")
        sql.append_string(&sid)
        sql.append_view("', '")
        sql.append_string(&lid)
        sql.append_view("', ")
        var st_str = underlayer_core::int_to_string(start_time)
        sql.append_view(st_str.to_view())
        sql.append_view(", 0, 'mixed', 0, 0)")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func insert_session(db : *DbClient, session : *Session) {
        var sql = string("INSERT OR IGNORE INTO sessions (id, learner_id, start_time, end_time, type, exercises_attempted, exercises_correct) VALUES ('")
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
        sql.append_view(")")
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
        sql.append_view(" WHERE id = '")
        sql.append_string(&sid)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

}
