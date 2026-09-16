// underlayer_repository — Study planner CRUD.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct StudyPlan {
        var id : string
        var learner_id : string
        var course_id : string
        var plan_date : string
        var start_hour : int
        var duration_minutes : int
        var focus_concepts : string
        var status : string
        var created_at : i64

        @make
        func make() : StudyPlan {
            return StudyPlan {
                id = string(),
                learner_id = string(),
                course_id = string(),
                plan_date = string(),
                start_hour = 0,
                duration_minutes = 30,
                focus_concepts = string(),
                status = string("planned"),
                created_at = 0
            }
        }
    }

    private func generate_plan_id() : string {
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

    public func create_plan(db : *DbClient, learner_id : &string, course_id : &string, plan_date : &string, start_hour : int, duration_minutes : int, focus_concepts : &string) : string {
        var plan_id = generate_plan_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var hour_str = underlayer_core::int_to_string(start_hour)
        var dur_str = underlayer_core::int_to_string(duration_minutes)
        var sql = string("INSERT INTO study_plans (id, learner_id, course_id, plan_date, start_hour, duration_minutes, focus_concepts, status, created_at) VALUES ('")
        sql.append_string(&plan_id)
        sql.append_view("', '")
        sql.append_view(learner_id.to_view())
        sql.append_view("', '")
        sql.append_view(course_id.to_view())
        sql.append_view("', '")
        sql.append_view(plan_date.to_view())
        sql.append_view("', ")
        sql.append_view(hour_str.to_view())
        sql.append_view(", ")
        sql.append_view(dur_str.to_view())
        sql.append_view(", '")
        sql.append_view(focus_concepts.to_view())
        sql.append_view("', 'planned', ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return plan_id
    }

    public func get_plans(db : *DbClient, learner_id : &string) : vector<StudyPlan> {
        var plans = vector<StudyPlan>()
        var sql = string("SELECT id, learner_id, course_id, plan_date, start_hour, duration_minutes, focus_concepts, status, created_at FROM study_plans WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' ORDER BY plan_date ASC, start_hour ASC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 9) {
                var p = StudyPlan::make()
                p.id = row.vals.get_ptr(0).copy()
                p.learner_id = row.vals.get_ptr(1).copy()
                p.course_id = row.vals.get_ptr(2).copy()
                p.plan_date = row.vals.get_ptr(3).copy()
                p.start_hour = parse_int(row.vals.get_ptr(4).to_view())
                p.duration_minutes = parse_int(row.vals.get_ptr(5).to_view())
                p.focus_concepts = row.vals.get_ptr(6).copy()
                p.status = row.vals.get_ptr(7).copy()
                p.created_at = parse_i64(row.vals.get_ptr(8).to_view())
                plans.push(p)
            }
            ri = ri + 1
        }
        return plans
    }

    public func get_plans_for_date(db : *DbClient, learner_id : &string, plan_date : &string) : vector<StudyPlan> {
        var plans = vector<StudyPlan>()
        var sql = string("SELECT id, learner_id, course_id, plan_date, start_hour, duration_minutes, focus_concepts, status, created_at FROM study_plans WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND plan_date = '")
        sql.append_view(plan_date.to_view())
        sql.append_view("' ORDER BY start_hour ASC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 9) {
                var p = StudyPlan::make()
                p.id = row.vals.get_ptr(0).copy()
                p.learner_id = row.vals.get_ptr(1).copy()
                p.course_id = row.vals.get_ptr(2).copy()
                p.plan_date = row.vals.get_ptr(3).copy()
                p.start_hour = parse_int(row.vals.get_ptr(4).to_view())
                p.duration_minutes = parse_int(row.vals.get_ptr(5).to_view())
                p.focus_concepts = row.vals.get_ptr(6).copy()
                p.status = row.vals.get_ptr(7).copy()
                p.created_at = parse_i64(row.vals.get_ptr(8).to_view())
                plans.push(p)
            }
            ri = ri + 1
        }
        return plans
    }

    public func get_plan(db : *DbClient, plan_id : &string) : StudyPlan {
        var sql = string("SELECT id, learner_id, course_id, plan_date, start_hour, duration_minutes, focus_concepts, status, created_at FROM study_plans WHERE id = '")
        sql.append_view(plan_id.to_view())
        sql.append_view("' LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 9) {
                var p = StudyPlan::make()
                p.id = row.vals.get_ptr(0).copy()
                p.learner_id = row.vals.get_ptr(1).copy()
                p.course_id = row.vals.get_ptr(2).copy()
                p.plan_date = row.vals.get_ptr(3).copy()
                p.start_hour = parse_int(row.vals.get_ptr(4).to_view())
                p.duration_minutes = parse_int(row.vals.get_ptr(5).to_view())
                p.focus_concepts = row.vals.get_ptr(6).copy()
                p.status = row.vals.get_ptr(7).copy()
                p.created_at = parse_i64(row.vals.get_ptr(8).to_view())
                return p
            }
        }
        return StudyPlan::make()
    }

    public func update_plan_status(db : *DbClient, plan_id : &string, status : &string) {
        var sql = string("UPDATE study_plans SET status = '")
        sql.append_view(status.to_view())
        sql.append_view("' WHERE id = '")
        sql.append_view(plan_id.to_view())
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func delete_plan(db : *DbClient, plan_id : &string) {
        var sql = string("DELETE FROM study_plans WHERE id = '")
        sql.append_view(plan_id.to_view())
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_upcoming_plans(db : *DbClient, learner_id : &string, days_ahead : int) : vector<StudyPlan> {
        var now = underlayer_core::current_timestamp()
        var day_offset : i64 = (days_ahead as i64) * 86400
        var future = now + day_offset
        // Convert future timestamp to YYYY-MM-DD for comparison
        // We use a simple approach: compare plan_date strings
        // For the date boundary, we format current time as YYYY-MM-DD
        var today_sec = now
        var day_secs : i64 = 86400
        var days_since_epoch = today_sec / day_secs
        // Approximate year calculation
        var year : i64 = 1970
        var remaining = days_since_epoch
        while(remaining >= 365) {
            var is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
            if(is_leap) { remaining = remaining - 366 } else { remaining = remaining - 365 }
            year = year + 1
        }
        var month : i64 = 1
        var days_in_months : [12]i64
        days_in_months[0] = 31
        var is_leap2 = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
        if(is_leap2) { days_in_months[1] = 29 } else { days_in_months[1] = 28 }
        days_in_months[2] = 31
        days_in_months[3] = 30
        days_in_months[4] = 31
        days_in_months[5] = 30
        days_in_months[6] = 31
        days_in_months[7] = 31
        days_in_months[8] = 30
        days_in_months[9] = 31
        days_in_months[10] = 30
        days_in_months[11] = 31
        while(month <= 12 && remaining >= days_in_months[(month - 1) as size_t]) {
            remaining = remaining - days_in_months[(month - 1) as size_t]
            month = month + 1
        }
        var day = remaining + 1
        var date_str = string()
        var y_str = underlayer_core::int_to_string(year)
        date_str.append_view(y_str.to_view())
        date_str.append_view("-")
        if(month < 10) { date_str.append_view("0") }
        var m_str = underlayer_core::int_to_string(month)
        date_str.append_view(m_str.to_view())
        date_str.append_view("-")
        if(day < 10) { date_str.append_view("0") }
        var d_str = underlayer_core::int_to_string(day)
        date_str.append_view(d_str.to_view())
        var plans = vector<StudyPlan>()
        var sql = string("SELECT id, learner_id, course_id, plan_date, start_hour, duration_minutes, focus_concepts, status, created_at FROM study_plans WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND plan_date >= '")
        sql.append_view(date_str.to_view())
        sql.append_view("' ORDER BY plan_date ASC, start_hour ASC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 9) {
                var p = StudyPlan::make()
                p.id = row.vals.get_ptr(0).copy()
                p.learner_id = row.vals.get_ptr(1).copy()
                p.course_id = row.vals.get_ptr(2).copy()
                p.plan_date = row.vals.get_ptr(3).copy()
                p.start_hour = parse_int(row.vals.get_ptr(4).to_view())
                p.duration_minutes = parse_int(row.vals.get_ptr(5).to_view())
                p.focus_concepts = row.vals.get_ptr(6).copy()
                p.status = row.vals.get_ptr(7).copy()
                p.created_at = parse_i64(row.vals.get_ptr(8).to_view())
                plans.push(p)
            }
            ri = ri + 1
        }
        return plans
    }

}
