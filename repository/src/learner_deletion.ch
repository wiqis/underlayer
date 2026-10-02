// underlayer_repository — deleting a learner, completely.
//
// WHY THIS FILE EXISTS.  Account deletion lived in web/src/handlers_data.ch as
// eleven hand-written DELETE statements, and it was wrong in three separate
// ways that only a row count could have found:
//
//  1. session_items NEVER DELETED ANYTHING.  The order was
//
//         DELETE FROM sessions              WHERE learner_id = ?
//         DELETE FROM session_items         WHERE session_id IN
//              (SELECT id FROM sessions WHERE learner_id = ?)
//
//     The subquery runs after the sessions are already gone, so it matches
//     nothing and every per-item study record -- which concept, what rating, how
//     long the learner spent on it -- survived the account.  A learner who
//     deleted their account kept their study history in the database.  This is
//     a delete of a CHILD table written after its PARENT, and it is invisible
//     because the statement is syntactically fine and returns 0 rows quietly.
//
//  2. ELEVEN TABLES WERE MISSED.  Not in the list at all: notifications,
//     learning_streaks, daily_activity, achievements, enrollments,
//     skill_assessments, bookmarks, learner_notes, study_plans, certificates,
//     course_reviews, exercise_attempts, email_verification_tokens.  After a
//     full account deletion the row counts showed 53 notifications, 8 streak
//     rows, 8 activity rows and others pointing at learners that no longer
//     existed.
//
//  3. IT RAN WITHOUT AUTH.  `handle_delete_account` resolved an absent token to
//     the shared `demo` learner and answered 200, so an unauthenticated
//     `DELETE /api/user/account` deleted the demo account.  handlers_data.ch now
//     returns 401 before calling anything here; this file refuses an empty
//     learner_id as well, so the mistake cannot be reintroduced by a caller.
//
// IT IS IN repository/ BECAUSE IT IS SQL.  The layering rule in AGENTS.md says
// all SQL lives below web/, and this was eleven statements above it.
//
// The statements are still built by concatenation, because that is what the
// whole repository does.  The caller passes a learner_id that came from a
// verified session row -- never from a request field -- and sql_escape is applied
// anyway.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    // Delete every row that belongs to `learner_id`, child tables before their
    // parents, and the learners row last.  Returns the number of learner-owned
    // tables it cleared, which the handler reports so the answer is checkable
    // rather than assumed -- `exec_sql` discards SQLite's error text, so a
    // caller that wants to know whether the delete worked has to look.
    public func delete_learner_everything(db : *DbClient, learner_id : &string) : i64 {
        if(learner_id.size() == 0) { return 0 }
        var lid = sql_escape(learner_id)

        // Child-of-sessions FIRST.  This ordering is the fix for defect 1; do
        // not "tidy" it back into the other order.
        var q = string("DELETE FROM session_items WHERE session_id IN (SELECT id FROM sessions WHERE learner_id = '")
        q.append_string(&lid)
        q.append_view("')")
        underlayer_db::exec_sql(db, &raw q)

        var cleared : i64 = 1

        // Tables keyed by learner_id directly.
        var direct = vector<string>()
        direct.push(string("concept_states"))
        direct.push(string("review_items"))
        direct.push(string("learning_goals"))
        direct.push(string("learner_notes"))
        direct.push(string("bookmarks"))
        direct.push(string("notifications"))
        direct.push(string("learning_streaks"))
        direct.push(string("daily_activity"))
        direct.push(string("achievements"))
        direct.push(string("enrollments"))
        direct.push(string("skill_assessments"))
        direct.push(string("study_plans"))
        direct.push(string("certificates"))
        direct.push(string("course_reviews"))
        direct.push(string("exercise_attempts"))
        direct.push(string("learner_profiles"))
        direct.push(string("learner_settings"))
        direct.push(string("learning_preferences"))
        direct.push(string("login_history"))
        direct.push(string("auth_sessions"))
        direct.push(string("password_reset_tokens"))
        direct.push(string("email_verification_tokens"))
        var di : size_t = 0
        while(di < direct.size()) {
            var t = direct.get_ptr(di).copy()
            var t_safe = sql_escape(&t)
            var stmt = string("DELETE FROM ")
            stmt.append_string(&t_safe)
            stmt.append_view(" WHERE learner_id = '")
            stmt.append_string(&lid)
            stmt.append_view("'")
            underlayer_db::exec_sql(db, &raw stmt)
            cleared = cleared + 1
            di = di + 1
        }

        // Parent after its child.
        var s = string("DELETE FROM sessions WHERE learner_id = '")
        s.append_string(&lid)
        s.append_view("'")
        underlayer_db::exec_sql(db, &raw s)
        cleared = cleared + 1

        var l = string("DELETE FROM learners WHERE id = '")
        l.append_string(&lid)
        l.append_view("'")
        var res = underlayer_db::exec_sql(db, &raw l)
        if(res.rows_affected > 0) { cleared = cleared + 1 }
        return cleared
    }

    // DELETE /api/user/data/:type — drop one category of a learner's data.
    // Same auth rule as above: the caller must resolve a real learner.
    public func delete_learner_data_of_type(db : *DbClient, learner_id : &string, data_type : &string) : bool {
        if(learner_id.size() == 0) { return false }
        var lid = sql_escape(learner_id)
        if(data_type.equals(&string("reviews"))) {
            var sql = string("DELETE FROM review_items WHERE learner_id = '")
            sql.append_string(&lid)
            sql.append_view("'")
            underlayer_db::exec_sql(db, &raw sql)
            return true
        }
        if(data_type.equals(&string("progress"))) {
            var sql = string("DELETE FROM concept_states WHERE learner_id = '")
            sql.append_string(&lid)
            sql.append_view("'")
            underlayer_db::exec_sql(db, &raw sql)
            return true
        }
        if(data_type.equals(&string("sessions"))) {
            var iq = string("DELETE FROM session_items WHERE session_id IN (SELECT id FROM sessions WHERE learner_id = '")
            iq.append_string(&lid)
            iq.append_view("')")
            underlayer_db::exec_sql(db, &raw iq)
            var sq = string("DELETE FROM sessions WHERE learner_id = '")
            sq.append_string(&lid)
            sq.append_view("'")
            underlayer_db::exec_sql(db, &raw sq)
            return true
        }
        if(data_type.equals(&string("all"))) {
            // Everything except the account itself.  "Delete my data" and
            // "delete my account" are different requests and they answer to
            // different routes; this one must never remove the learners row.
            var lg = string("DELETE FROM learning_goals WHERE learner_id = '")
            lg.append_string(&lid)
            lg.append_view("'")
            underlayer_db::exec_sql(db, &raw lg)
            var nt = string("DELETE FROM notifications WHERE learner_id = '")
            nt.append_string(&lid)
            nt.append_view("'")
            underlayer_db::exec_sql(db, &raw nt)
            var ls = string("DELETE FROM learning_streaks WHERE learner_id = '")
            ls.append_string(&lid)
            ls.append_view("'")
            underlayer_db::exec_sql(db, &raw ls)
            var da = string("DELETE FROM daily_activity WHERE learner_id = '")
            da.append_string(&lid)
            da.append_view("'")
            underlayer_db::exec_sql(db, &raw da)
            var ach = string("DELETE FROM achievements WHERE learner_id = '")
            ach.append_string(&lid)
            ach.append_view("'")
            underlayer_db::exec_sql(db, &raw ach)
            var enr = string("DELETE FROM enrollments WHERE learner_id = '")
            enr.append_string(&lid)
            enr.append_view("'")
            underlayer_db::exec_sql(db, &raw enr)
            var sa = string("DELETE FROM skill_assessments WHERE learner_id = '")
            sa.append_string(&lid)
            sa.append_view("'")
            underlayer_db::exec_sql(db, &raw sa)
            return true
        }
        return false
    }

}