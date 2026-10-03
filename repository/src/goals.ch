// underlayer_repository — Learning goals CRUD (6.1.5).
using std::string
using std::vector
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
        // The id must be unique, and it used to be the timestamp.
        //
        // `id` is the PRIMARY KEY and `now` has one-second resolution, so two
        // goals set inside the same second collided and the second INSERT was
        // dropped on the primary key. exec_sql's result is not checked, so the
        // endpoint still answered {"ok":true} and the goal was simply gone.
        //
        // Measured, on a learner setting goals for elf and a64asm back to back:
        //   POST elf     -> {"ok":true,"course_id":"elf"}
        //   POST a64asm  -> {"ok":true,"course_id":"a64asm"}
        //   GET  /api/goals -> {"count":1, "goals":["elf"]}      <- a64asm lost
        // Repeating the same two POSTs two seconds apart gave count 2, which is
        // what identified the collision as the cause rather than the filter.
        //
        // generate_goal_id matches how enrollments.ch and bookmarks.ch already
        // mint ids in this layer (16 random bytes, hex encoded), so the fix uses
        // the convention that is already here rather than a new scheme.
        var goal_id = generate_goal_id()
        var sql = string("INSERT INTO learning_goals (id, learner_id, course_id, target_date, created_at) VALUES ('")
        sql.append_string(&goal_id)
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

    // 32 hex chars of osrand entropy — the same shape as generate_enrollment_id
    // and generate_bookmark_id. The timestamp is still recorded in created_at,
    // which is what the ordering and the display use; it was never the right
    // thing to be the key.
    private func generate_goal_id() : string {
        var buf : [16]u8
        osrand::random_fill(&raw mut buf[0], 16)
        var hex_out : [33]char
        var i0 : size_t = 0
        while(i0 < 33) { hex_out[i0] = 0; i0 = i0 + 1 }
        encoding::hex_encode(&raw buf[0], 16, &raw mut hex_out[0], 33)
        var result = string()
        var i : size_t = 0
        while(i < 32 && hex_out[i] != 0) { result.append(hex_out[i]); i = i + 1 }
        return result
    }

    // A stored goal, for the read side.  6.1.5 shipped POST and DELETE with no
    // GET, so a learner could set a target date and then never read it back --
    // the one thing a goal is for.  See list_learning_goals below.
    public struct LearningGoal {
        var id : string
        var course_id : string
        var target_date : i64
        var created_at : i64

        @make
        func make() : LearningGoal {
            return LearningGoal {
                id = string(),
                course_id = string(),
                target_date = 0,
                created_at = 0
            }
        }
    }

    // Every goal a learner has set, newest first.  The per-course
    // get_learning_goal above answers "is there a goal for elf?", which is the
    // wrong question for a UI that has to show every goal it knows about: the
    // platform ships 34 courses and the learner may have set one for each.
    public func list_learning_goals(db : *DbClient, learner_id : &string) : vector<LearningGoal> {
        var goals = vector<LearningGoal>()
        var sql = string("SELECT id, course_id, target_date, created_at FROM learning_goals WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' ORDER BY created_at DESC")
        var db_result = underlayer_db::query_sql(db, &raw sql)
        var i : size_t = 0
        while(i < db_result.rows.size()) {
            var row = db_result.rows.get_ptr(i)
            if(row.vals.size() >= 4) {
                var goal = LearningGoal::make()
                goal.id = row.vals.get_ptr(0).copy()
                goal.course_id = row.vals.get_ptr(1).copy()
                goal.target_date = parse_i64(row.vals.get_ptr(2).to_view())
                goal.created_at = parse_i64(row.vals.get_ptr(3).to_view())
                goals.push_back(goal)
            }
            i = i + 1
        }
        return goals
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
