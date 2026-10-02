// underlayer_repository — Content feedback & exercise report CRUD.
//
// THERE IS NO ADMIN ROLE ON THIS PLATFORM, and that fact decides the shape of
// this file.  The `learners` table is (id, name, email, password_hash,
// created_at) — no role column, no is_admin, no membership table — and
// `handlers_settings.ch` has no role concept either.  A named administrator is
// therefore not something this codebase can express, and inventing one here
// would be inventing the feature rather than fixing the defect.
//
// So: every read in this file is scoped to a learner, and the two cross-learner
// queries (`get_all_pending_feedback`, `get_all_exercise_reports`) are kept but
// are NOT reachable from any route — see web/src/handlers_feedback_admin.ch,
// which refuses them with 403 and says why.  The consequence is recorded rather
// than hidden: **feedback triage is unreachable through the API.**  Nobody can
// mark a learner's feedback resolved or write an admin_note, so `status` and
// `admin_notes` are write-once columns for now.  When a role exists, the two
// functions below are already the queries it wants, and only the handler gate
// has to change.
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

    public struct FeedbackStats {
        var feedback_type : string
        var count : int
        var pending : int

        @make
        func make() : FeedbackStats {
            return FeedbackStats { feedback_type = string(), count = 0, pending = 0 }
        }
    }

    // public: exercise_reports.ch mints its ids here, because they come from
    // the same 16 bytes of CSPRNG output and there is no reason for two
    // id schemes to exist in one table family.
    public func generate_feedback_id() : string {
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
        var lid = sql_escape(&feedback.learner_id)
        var cid = sql_escape(&feedback.concept_id)
        var crs = sql_escape(&feedback.course_id)
        var ftype = sql_escape(&feedback.feedback_type)
        var purl = sql_escape(&feedback.page_url)
        var msg_esc = underlayer_core::json_escape(&feedback.message.to_view())
        var sql = string("INSERT INTO content_feedback (id, learner_id, concept_id, course_id, feedback_type, message, page_url, status, created_at, updated_at) VALUES ('")
        sql.append_string(&fb_id)
        sql.append_view("', '")
        sql.append_string(&lid)
        sql.append_view("', '")
        sql.append_string(&cid)
        sql.append_view("', '")
        sql.append_string(&crs)
        sql.append_view("', '")
        sql.append_string(&ftype)
        sql.append_view("', '")
        sql.append_view(msg_esc.to_view())
        sql.append_view("', '")
        sql.append_string(&purl)
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

    // OWNER-SCOPED.  This used to be `WHERE concept_id = '...'` and nothing
    // else, and it was called with no learner_id at all, so
    // `GET /api/feedback/concept/:conceptId` answered 200 to an anonymous
    // request with every learner's feedback for that concept -- learner_id,
    // message, status and admin_notes.  A learner's own report about a course
    // is their words about content they are studying; there is no reading of
    // this table in which every learner gets every other learner's.
    //
    // There is deliberately no unscoped twin of this function.  One read path,
    // scoped, is the shape that stays fixed; a `get_feedback_for_concept`
    // sitting next to it would be one call away from being wired back up.
    public func get_feedback_for_learner_concept(db : *DbClient, learner_id : &string, concept_id : &string) : vector<ContentFeedback> {
        var feedbacks = vector<ContentFeedback>()
        if(learner_id.size() == 0) { return feedbacks }
        var lid = sql_escape(learner_id)
        var cid = sql_escape(concept_id)
        var sql = string("SELECT id, learner_id, concept_id, course_id, feedback_type, message, page_url, status, admin_notes, created_at, updated_at FROM content_feedback WHERE learner_id = '")
        sql.append_string(&lid)
        sql.append_view("' AND concept_id = '")
        sql.append_string(&cid)
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

    // Every pending report from every learner.  NOT REACHABLE from any route:
    // see the file header and web/src/handlers_feedback_admin.ch.
    public func get_all_pending_feedback(db : *DbClient) : vector<ContentFeedback> {
        var sql = string("SELECT id, learner_id, concept_id, course_id, feedback_type, message, page_url, status, admin_notes, created_at, updated_at FROM content_feedback WHERE status = 'pending' ORDER BY created_at DESC")
        return read_feedback_rows(db, &raw sql)
    }

    // public for the same reason as read_report_rows in exercise_reports.ch:
    // one row-mapping loop, two WHERE clauses.
    public func read_feedback_rows(db : *DbClient, sql : *string) : vector<ContentFeedback> {
        var feedbacks = vector<ContentFeedback>()
        var result = underlayer_db::query_sql(db, sql)
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

    // Closes a feedback row and writes the reviewer's note.  NOT REACHABLE from
    // any route while there is no reviewer role -- PUT /api/feedback/:id/status
    // answers 403 (see web/src/handlers_feedback_admin.ch).  It is kept because
    // it is the write half of what a reviewer role needs, and deleting it would
    // mean rewriting the SQL when the role arrives.
    public func update_feedback_status(db : *DbClient, feedback_id : &string, status : &string, admin_notes : *string) {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var fid = sql_escape(feedback_id)
        var st = sql_escape(status)
        var sql = string("UPDATE content_feedback SET status = '")
        sql.append_string(&st)
        sql.append_view("', admin_notes = '")
        var notes_esc = underlayer_core::json_escape(&admin_notes.to_view())
        sql.append_view(notes_esc.to_view())
        sql.append_view("', updated_at = ")
        sql.append_view(now_str.to_view())
        sql.append_view(" WHERE id = '")
        sql.append_string(&fid)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
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
