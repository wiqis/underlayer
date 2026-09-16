// underlayer_repository — Enrollment CRUD.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct Enrollment {
        var id : string
        var learner_id : string
        var course_id : string
        var enrolled_at : i64
        var last_accessed : i64
        var completed_at : i64
        var status : string

        @make
        func make() : Enrollment {
            return Enrollment {
                id = string(),
                learner_id = string(),
                course_id = string(),
                enrolled_at = 0,
                last_accessed = 0,
                completed_at = 0,
                status = string("active")
            }
        }
    }

    private func generate_enrollment_id() : string {
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

    public func enroll_learner(db : *DbClient, learner_id : &string, course_id : &string) : string {
        var enrollment_id = generate_enrollment_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT INTO enrollments (id, learner_id, course_id, enrolled_at, last_accessed, status) VALUES ('")
        sql.append_string(&enrollment_id)
        sql.append_view("', '")
        sql.append_view(learner_id.to_view())
        sql.append_view("', '")
        sql.append_view(course_id.to_view())
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(", 'active')")
        underlayer_db::exec_sql(db, &raw sql)
        return enrollment_id
    }

    public func get_enrollment(db : *DbClient, learner_id : &string, course_id : &string) : Enrollment {
        var enrollment = Enrollment::make()
        var sql = string("SELECT id, learner_id, course_id, enrolled_at, last_accessed, completed_at, status FROM enrollments WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' AND course_id = '")
        sql.append_view(course_id.to_view())
        sql.append_view("' LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 7) {
                enrollment.id = row.vals.get_ptr(0).copy()
                enrollment.learner_id = row.vals.get_ptr(1).copy()
                enrollment.course_id = row.vals.get_ptr(2).copy()
                enrollment.enrolled_at = parse_i64(row.vals.get_ptr(3).to_view())
                enrollment.last_accessed = parse_i64(row.vals.get_ptr(4).to_view())
                enrollment.completed_at = parse_i64(row.vals.get_ptr(5).to_view())
                enrollment.status = row.vals.get_ptr(6).copy()
            }
        }
        return enrollment
    }

    public func get_learner_enrollments(db : *DbClient, learner_id : &string) : vector<Enrollment> {
        var enrollments = vector<Enrollment>()
        var sql = string("SELECT id, learner_id, course_id, enrolled_at, last_accessed, completed_at, status FROM enrollments WHERE learner_id = '")
        sql.append_view(learner_id.to_view())
        sql.append_view("' ORDER BY enrolled_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 7) {
                var e = Enrollment::make()
                e.id = row.vals.get_ptr(0).copy()
                e.learner_id = row.vals.get_ptr(1).copy()
                e.course_id = row.vals.get_ptr(2).copy()
                e.enrolled_at = parse_i64(row.vals.get_ptr(3).to_view())
                e.last_accessed = parse_i64(row.vals.get_ptr(4).to_view())
                e.completed_at = parse_i64(row.vals.get_ptr(5).to_view())
                e.status = row.vals.get_ptr(6).copy()
                enrollments.push(e)
            }
            ri = ri + 1
        }
        return enrollments
    }

    public func update_last_accessed(db : *DbClient, enrollment_id : &string) {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("UPDATE enrollments SET last_accessed = ")
        sql.append_view(now_str.to_view())
        sql.append_view(" WHERE id = '")
        sql.append_view(enrollment_id.to_view())
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func complete_enrollment(db : *DbClient, enrollment_id : &string) {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("UPDATE enrollments SET status = 'completed', completed_at = ")
        sql.append_view(now_str.to_view())
        sql.append_view(" WHERE id = '")
        sql.append_view(enrollment_id.to_view())
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

}
