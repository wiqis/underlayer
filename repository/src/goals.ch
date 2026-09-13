// underlayer_repository — Learning goals CRUD (6.1.5).
using std::string
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct GoalResult {
        var id : string
        var target_date : i64
        var found : bool

        @make
        func make() : GoalResult {
            return GoalResult {
                id = string(),
                target_date = 0,
                found = false
            }
        }
    }

    // Get the current goal for a learner + course
    public func get_learning_goal(db : *DbClient, learner_id : &string, course_id : &string) : GoalResult {
        var result = GoalResult::make()
        var sql = string("SELECT id, target_date FROM learning_goals WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("' ORDER BY created_at DESC LIMIT 1")
        var db_result = underlayer_db::query_sql(db, &raw sql)
        if(db_result.rows.size() > 0) {
            var row = db_result.rows.get_ptr(0)
            if(row.vals.size() >= 2) {
                result.id = row.vals.get_ptr(0).copy()
                result.target_date = parse_i64(row.vals.get_ptr(1).to_view())
                result.found = true
            }
        }
        return result
    }

    // Set or update a learning goal
    public func set_learning_goal(db : *DbClient, learner_id : &string, course_id : &string, target_date : i64) {
        // Delete existing goal for this course
        var del_sql = string("DELETE FROM learning_goals WHERE learner_id = '")
        del_sql.append_string(learner_id)
        del_sql.append_view("' AND course_id = '")
        del_sql.append_string(course_id)
        del_sql.append_view("'")
        underlayer_db::exec_sql(db, &raw del_sql)
        // Insert new goal
        var now = underlayer_core::current_timestamp()
        var id_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT INTO learning_goals (id, learner_id, course_id, target_date, created_at) VALUES ('")
        sql.append_view(id_str.to_view())
        sql.append_view("', '")
        sql.append_string(learner_id)
        sql.append_view("', '")
        sql.append_string(course_id)
        sql.append_view("', ")
        var td_str = underlayer_core::int_to_string(target_date)
        sql.append_view(td_str.to_view())
        sql.append_view(", ")
        var now_str = underlayer_core::int_to_string(now)
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // Delete a learning goal
    public func delete_learning_goal(db : *DbClient, learner_id : &string, course_id : &string) {
        var sql = string("DELETE FROM learning_goals WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

}
