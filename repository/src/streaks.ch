// underlayer_repository — Learning streaks tracking.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct StreakData {
        var learner_id : string
        var current_streak : int
        var longest_streak : int
        var total_active_days : int
        var last_active_date : string

        @make
        func make() : StreakData {
            return StreakData {
                learner_id = string(),
                current_streak = 0,
                longest_streak = 0,
                total_active_days = 0,
                last_active_date = string()
            }
        }
    }

    public struct DayActivity {
        var date : string
        var active : bool
        var sessions : int

        @make
        func make() : DayActivity {
            return DayActivity {
                date = string(),
                active = false,
                sessions = 0
            }
        }
    }

    // Record activity for today. Updates streak logic.
    public func record_activity(db : *DbClient, learner_id : &string) : StreakData {
        var now = underlayer_core::current_timestamp()
        var today = underlayer_core::date_string(now)
        var yesterday = underlayer_core::date_string_subtract_days(&today.to_view(), 1)

        // Check if already active today
        var check_sql = string("SELECT sessions_count FROM daily_activity WHERE learner_id = '")
        check_sql.append_string(learner_id)
        check_sql.append_view("' AND activity_date = '")
        check_sql.append_string(&today)
        check_sql.append_view("'")
        var check_result = underlayer_db::query_sql(db, &raw check_sql)

        if(check_result.rows.size() > 0) {
            // Already active today — increment session count
            var inc_sql = string("UPDATE daily_activity SET sessions_count = sessions_count + 1 WHERE learner_id = '")
            inc_sql.append_string(learner_id)
            inc_sql.append_view("' AND activity_date = '")
            inc_sql.append_string(&today)
            inc_sql.append_view("'")
            underlayer_db::exec_sql(db, &raw inc_sql)
        } else {
            // First activity today — insert new row
            var ins_sql = string("INSERT INTO daily_activity (learner_id, activity_date, sessions_count) VALUES ('")
            ins_sql.append_string(learner_id)
            ins_sql.append_view("', '")
            ins_sql.append_string(&today)
            ins_sql.append_view("', 1)")
            underlayer_db::exec_sql(db, &raw ins_sql)
        }

        // Load current streak data
        var streak = get_streak(db, learner_id)
        streak.learner_id = learner_id.copy()

        if(streak.last_active_date.equals(&today)) {
            // Already updated streak today — no change
        } else {
            if(streak.last_active_date.equals(&yesterday)) {
                // Consecutive day — extend streak
                streak.current_streak = streak.current_streak + 1
            } else {
                // Streak broken or first day — reset to 1
                streak.current_streak = 1
            }
            streak.total_active_days = streak.total_active_days + 1
            streak.last_active_date = today.copy()
            if(streak.current_streak > streak.longest_streak) {
                streak.longest_streak = streak.current_streak
            }
        }

        // Persist streak (insert or update)
        var exists_sql = string("SELECT learner_id FROM learning_streaks WHERE learner_id = '")
        exists_sql.append_string(learner_id)
        exists_sql.append_view("'")
        var exists_result = underlayer_db::query_sql(db, &raw exists_sql)

        if(exists_result.rows.size() > 0) {
            var upd_sql = string("UPDATE learning_streaks SET current_streak = ")
            var cs_str = underlayer_core::int_to_string(streak.current_streak as i64)
            upd_sql.append_view(cs_str.to_view())
            upd_sql.append_view(", longest_streak = ")
            var ls_str = underlayer_core::int_to_string(streak.longest_streak as i64)
            upd_sql.append_view(ls_str.to_view())
            upd_sql.append_view(", total_active_days = ")
            var tad_str = underlayer_core::int_to_string(streak.total_active_days as i64)
            upd_sql.append_view(tad_str.to_view())
            upd_sql.append_view(", last_active_date = '")
            upd_sql.append_string(&streak.last_active_date)
            upd_sql.append_view("' WHERE learner_id = '")
            upd_sql.append_string(learner_id)
            upd_sql.append_view("'")
            underlayer_db::exec_sql(db, &raw upd_sql)
        } else {
            var ins_sql2 = string("INSERT INTO learning_streaks (learner_id, current_streak, longest_streak, total_active_days, last_active_date) VALUES ('")
            ins_sql2.append_string(learner_id)
            ins_sql2.append_view("', ")
            var cs_str2 = underlayer_core::int_to_string(streak.current_streak as i64)
            ins_sql2.append_view(cs_str2.to_view())
            ins_sql2.append_view(", ")
            var ls_str2 = underlayer_core::int_to_string(streak.longest_streak as i64)
            ins_sql2.append_view(ls_str2.to_view())
            ins_sql2.append_view(", ")
            var tad_str2 = underlayer_core::int_to_string(streak.total_active_days as i64)
            ins_sql2.append_view(tad_str2.to_view())
            ins_sql2.append_view(", '")
            ins_sql2.append_string(&streak.last_active_date)
            ins_sql2.append_view("')")
            underlayer_db::exec_sql(db, &raw ins_sql2)
        }

        return streak
    }

    // Get current streak data for a learner.
    public func get_streak(db : *DbClient, learner_id : &string) : StreakData {
        var streak = StreakData::make()
        streak.learner_id = learner_id.copy()
        var sql = string("SELECT current_streak, longest_streak, total_active_days, last_active_date FROM learning_streaks WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 4) {
                streak.current_streak = parse_int(row.vals.get_ptr(0).to_view())
                streak.longest_streak = parse_int(row.vals.get_ptr(1).to_view())
                streak.total_active_days = parse_int(row.vals.get_ptr(2).to_view())
                streak.last_active_date = row.vals.get_ptr(3).copy()
            }
        }
        // Check if streak is broken (last active was not yesterday or today)
        if(streak.last_active_date.size() > 0 && streak.current_streak > 0) {
            var now = underlayer_core::current_timestamp()
            var today = underlayer_core::date_string(now)
            var yesterday = underlayer_core::date_string_subtract_days(&today.to_view(), 1)
            if(!streak.last_active_date.equals(&today) && !streak.last_active_date.equals(&yesterday)) {
                streak.current_streak = 0
            }
        }
        return streak
    }

    // Get last 7 days of activity for a learner.
    public func get_weekly_activity(db : *DbClient, learner_id : &string) : vector<DayActivity> {
        var now = underlayer_core::current_timestamp()
        var today = underlayer_core::date_string(now)
        var result = vector<DayActivity>()
        var i : int = 6
        while(i >= 0) {
            var day_date = underlayer_core::date_string_subtract_days(&today.to_view(), i)
            var activity = DayActivity::make()
            activity.date = day_date.copy()
            var sql = string("SELECT sessions_count FROM daily_activity WHERE learner_id = '")
            sql.append_string(learner_id)
            sql.append_view("' AND activity_date = '")
            sql.append_string(&day_date)
            sql.append_view("'")
            var db_result = underlayer_db::query_sql(db, &raw sql)
            if(db_result.rows.size() > 0) {
                var row = db_result.rows.get_ptr(0)
                if(row.vals.size() >= 1) {
                    activity.sessions = parse_int(row.vals.get_ptr(0).to_view())
                    activity.active = activity.sessions > 0
                }
            }
            result.push(activity)
            i = i - 1
        }
        return result
    }

}