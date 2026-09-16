// underlayer_repository — Content feedback & exercise report CRUD.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct ContentFeedback {
        var id : string
        var learner_id : string
        var concept_id : string
        var course_id : string
        var feedback_type : string
        var message : string
        var page_url : string
        var status : string
        var admin_notes : string
        var created_at : i64
        var updated_at : i64

        @make
        func make() : ContentFeedback {
            return ContentFeedback { id = string(), learner_id = string(), concept_id = string(), course_id = string(), feedback_type = string(), message = string(), page_url = string(), status = string("pending"), admin_notes = string(), created_at = 0, updated_at = 0 }
        }
    }

    public struct ExerciseReport {
        var id : string
        var learner_id : string
        var exercise_id : string
        var concept_id : string
        var report_type : string
        var message : string
        var status : string
        var created_at : i64

        @make
        func make() : ExerciseReport {
            return ExerciseReport { id = string(), learner_id = string(), exercise_id = string(), concept_id = string(), report_type = string(), message = string(), status = string("pending"), created_at = 0 }
        }
    }

    public struct FeedbackStats {
        var feedback_type : string
        var count : int
        var pending : int

        @make
        func make() : FeedbackStats {
            return FeedbackStats { feedback_type = string(), count = 0, pending = 0 }
        }
    }

    private func generate_feedback_id() : string {
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

    public func submit_feedback(db : *DbClient, feedback : *ContentFeedback) : string {
        var fb_id = generate_feedback_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT INTO content_feedback (id, learner_id, concept_id, course_id, feedback_type, message, page_url, status, created_at, updated_at) VALUES ('")
        sql.append_string(&fb_id)
        sql.append_view("', '")
        sql.append_string(&feedback.learner_id)
        sql.append_view("', '")
        sql.append_string(&feedback.concept_id)
        sql.append_view("', '")
        sql.append_string(&feedback.course_id)
        sql.append_view("', '")
        sql.append_string(&feedback.feedback_type)
        sql.append_view("', '")
        var msg_esc = underlayer_core::json_escape(&feedback.message.to_view())
        sql.append_view(msg_esc.to_view())
        sql.append_view("', '")
        sql.append_string(&feedback.page_url)
        sql.append_view("', '")
        sql.append_string(&feedback.status)
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return fb_id
    }

    public func get_feedback_for_concept(db : *DbClient, concept_id : &string) : vector<ContentFeedback> {
        var feedbacks = vector<ContentFeedback>()
        var sql = string("SELECT id, learner_id, concept_id, course_id, feedback_type, message, page_url, status, admin_notes, created_at, updated_at FROM content_feedback WHERE concept_id = '")
        sql.append_string(concept_id)
        sql.append_view("' ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 11) {
                var fb = ContentFeedback::make()
                fb.id = row.vals.get_ptr(0).copy()
                fb.learner_id = row.vals.get_ptr(1).copy()
                fb.concept_id = row.vals.get_ptr(2).copy()
                fb.course_id = row.vals.get_ptr(3).copy()
                fb.feedback_type = row.vals.get_ptr(4).copy()
                fb.message = row.vals.get_ptr(5).copy()
                fb.page_url = row.vals.get_ptr(6).copy()
                fb.status = row.vals.get_ptr(7).copy()
                fb.admin_notes = row.vals.get_ptr(8).copy()
                fb.created_at = parse_i64(row.vals.get_ptr(9).to_view())
                fb.updated_at = parse_i64(row.vals.get_ptr(10).to_view())
                feedbacks.push(fb)
            }
            ri = ri + 1
        }
        return feedbacks
    }

    public func get_all_pending_feedback(db : *DbClient) : vector<ContentFeedback> {
        var feedbacks = vector<ContentFeedback>()
        var sql = string("SELECT id, learner_id, concept_id, course_id, feedback_type, message, page_url, status, admin_notes, created_at, updated_at FROM content_feedback WHERE status = 'pending' ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 11) {
                var fb = ContentFeedback::make()
                fb.id = row.vals.get_ptr(0).copy()
                fb.learner_id = row.vals.get_ptr(1).copy()
                fb.concept_id = row.vals.get_ptr(2).copy()
                fb.course_id = row.vals.get_ptr(3).copy()
                fb.feedback_type = row.vals.get_ptr(4).copy()
                fb.message = row.vals.get_ptr(5).copy()
                fb.page_url = row.vals.get_ptr(6).copy()
                fb.status = row.vals.get_ptr(7).copy()
                fb.admin_notes = row.vals.get_ptr(8).copy()
                fb.created_at = parse_i64(row.vals.get_ptr(9).to_view())
                fb.updated_at = parse_i64(row.vals.get_ptr(10).to_view())
                feedbacks.push(fb)
            }
            ri = ri + 1
        }
        return feedbacks
    }

    public func update_feedback_status(db : *DbClient, feedback_id : &string, status : &string, admin_notes : *string) {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("UPDATE content_feedback SET status = '")
        sql.append_string(status)
        sql.append_view("', admin_notes = '")
        var notes_esc = underlayer_core::json_escape(&admin_notes.to_view())
        sql.append_view(notes_esc.to_view())
        sql.append_view("', updated_at = ")
        sql.append_view(now_str.to_view())
        sql.append_view(" WHERE id = '")
        sql.append_string(feedback_id)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func report_exercise(db : *DbClient, report : *ExerciseReport) : string {
        var report_id = generate_feedback_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT INTO exercise_reports (id, learner_id, exercise_id, concept_id, report_type, message, status, created_at) VALUES ('")
        sql.append_string(&report_id)
        sql.append_view("', '")
        sql.append_string(&report.learner_id)
        sql.append_view("', '")
        sql.append_string(&report.exercise_id)
        sql.append_view("', '")
        sql.append_string(&report.concept_id)
        sql.append_view("', '")
        sql.append_string(&report.report_type)
        sql.append_view("', '")
        var msg_esc = underlayer_core::json_escape(&report.message.to_view())
        sql.append_view(msg_esc.to_view())
        sql.append_view("', '")
        sql.append_string(&report.status)
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return report_id
    }

    public func get_exercise_reports(db : *DbClient, exercise_id : &string) : vector<ExerciseReport> {
        var reports = vector<ExerciseReport>()
        var sql = string("SELECT id, learner_id, exercise_id, concept_id, report_type, message, status, created_at FROM exercise_reports WHERE exercise_id = '")
        sql.append_string(exercise_id)
        sql.append_view("' ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 8) {
                var r = ExerciseReport::make()
                r.id = row.vals.get_ptr(0).copy()
                r.learner_id = row.vals.get_ptr(1).copy()
                r.exercise_id = row.vals.get_ptr(2).copy()
                r.concept_id = row.vals.get_ptr(3).copy()
                r.report_type = row.vals.get_ptr(4).copy()
                r.message = row.vals.get_ptr(5).copy()
                r.status = row.vals.get_ptr(6).copy()
                r.created_at = parse_i64(row.vals.get_ptr(7).to_view())
                reports.push(r)
            }
            ri = ri + 1
        }
        return reports
    }

    public func get_all_exercise_reports(db : *DbClient) : vector<ExerciseReport> {
        var reports = vector<ExerciseReport>()
        var sql = string("SELECT id, learner_id, exercise_id, concept_id, report_type, message, status, created_at FROM exercise_reports ORDER BY created_at DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 8) {
                var r = ExerciseReport::make()
                r.id = row.vals.get_ptr(0).copy()
                r.learner_id = row.vals.get_ptr(1).copy()
                r.exercise_id = row.vals.get_ptr(2).copy()
                r.concept_id = row.vals.get_ptr(3).copy()
                r.report_type = row.vals.get_ptr(4).copy()
                r.message = row.vals.get_ptr(5).copy()
                r.status = row.vals.get_ptr(6).copy()
                r.created_at = parse_i64(row.vals.get_ptr(7).to_view())
                reports.push(r)
            }
            ri = ri + 1
        }
        return reports
    }

    public func get_feedback_stats(db : *DbClient) : vector<FeedbackStats> {
        var stats = vector<FeedbackStats>()
        var sql = string("SELECT feedback_type, COUNT(*) as cnt, SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pend FROM content_feedback GROUP BY feedback_type ORDER BY cnt DESC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 3) {
                var s = FeedbackStats::make()
                s.feedback_type = row.vals.get_ptr(0).copy()
                s.count = parse_i64(row.vals.get_ptr(1).to_view()) as int
                s.pending = parse_i64(row.vals.get_ptr(2).to_view()) as int
                stats.push(s)
            }
            ri = ri + 1
        }
        return stats
    }

}
