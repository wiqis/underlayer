// underlayer_repository — Exercise reports: "this question is wrong".
//
// SPLIT OUT OF feedback.ch because that file was 264 lines before this work
// and is over the 250-line ceiling in AGENTS.md; content feedback and exercise
// reports are two tables with two shapes, and the id generator is the only
// thing they share.
//
// The same rule as feedback.ch applies here: there is no admin role, so
// `get_all_exercise_reports` is not reachable from any route (see
// web/src/handlers_feedback_admin.ch, which refuses it with 403 and says why).
// A learner can file a report and can read back the reports they filed.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

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

    public func report_exercise(db : *DbClient, report : *ExerciseReport) : string {
        var report_id = generate_feedback_id()
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var lid = sql_escape(&report.learner_id)
        var eid = sql_escape(&report.exercise_id)
        var cid = sql_escape(&report.concept_id)
        var rtype = sql_escape(&report.report_type)
        var msg_esc = underlayer_core::json_escape(&report.message.to_view())
        var sql = string("INSERT INTO exercise_reports (id, learner_id, exercise_id, concept_id, report_type, message, status, created_at) VALUES ('")
        sql.append_string(&report_id)
        sql.append_view("', '")
        sql.append_string(&lid)
        sql.append_view("', '")
        sql.append_string(&eid)
        sql.append_view("', '")
        sql.append_string(&cid)
        sql.append_view("', '")
        sql.append_string(&rtype)
        sql.append_view("', '")
        sql.append_view(msg_esc.to_view())
        sql.append_view("', '")
        sql.append_string(&report.status)
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return report_id
    }

    // Reports left about ONE exercise, across learners.  Kept for the day a
    // reviewer role exists; no route has ever called it, so it is not new
    // surface -- it is the query that was already written and already unused.
    public func get_exercise_reports(db : *DbClient, exercise_id : &string) : vector<ExerciseReport> {
        var reports = vector<ExerciseReport>()
        var eid = sql_escape(exercise_id)
        var sql = string("SELECT id, learner_id, exercise_id, concept_id, report_type, message, status, created_at FROM exercise_reports WHERE exercise_id = '")
        sql.append_string(&eid)
        sql.append_view("' ORDER BY created_at DESC")
        return read_report_rows(db, &raw sql)
    }

    // Every report from every learner.  NOT REACHABLE: see the file header.
    public func get_all_exercise_reports(db : *DbClient) : vector<ExerciseReport> {
        var sql = string("SELECT id, learner_id, exercise_id, concept_id, report_type, message, status, created_at FROM exercise_reports ORDER BY created_at DESC")
        return read_report_rows(db, &raw sql)
    }

    // public because the two queries above are byte-identical apart from their
    // WHERE clause, and a third copy of this loop is how the row-index bug
    // would happen again.
    public func read_report_rows(db : *DbClient, sql : *string) : vector<ExerciseReport> {
        var reports = vector<ExerciseReport>()
        var result = underlayer_db::query_sql(db, sql)
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

}
