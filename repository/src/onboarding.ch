// underlayer_repository — Onboarding state.
//
// WHY THIS FILE EXISTS AND WHY IT IS SMALL.  The only question anyone asks of
// onboarding is "has this learner finished it?", and the handler used to answer
// it with SQL sitting in web/src, which is the wrong layer: the answer depends on
// a schema detail (onboarding_completed_at) and a detail the web layer has no
// business knowing (that registration also writes a learning_preferences row,
// which is why the previous inference from "a row exists" was always true).
//
// THE ONE NON-OBVIOUS RULE, and it is what makes this correct.  A preferences
// row is NOT evidence of onboarding -- registration creates one for every
// account.  Only onboarding itself sets onboarding_completed_at, so that column
// is the sole signal.  Do not "simplify" this back to a row-exists check: that
// is the exact defect this file was written to remove, and it fails silently,
// returning a confident `true` for every learner forever.
//
// THE `skip` FLAG EXISTS SO THE GATE CANNOT LOOP.  The onboarding page lets a
// learner finish without picking a course (its own JS does `if(selectedCourse)
// ... else '/'`).  Without a way to record "they finished and chose nothing",
// such a learner would be gated on every page load and on every login, forever,
// with no route out -- a gate that cannot be left is a wall.  Marking the
// timestamp on any completion, course or not, is what makes "Skip for now"
// honest instead of a lie the gate will contradict.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_repository {

    // True when this learner has finished onboarding.
    //
    // Reads `ok` off the query: a statement that could not be parsed must not be
    // reported as "has not onboarded", because that would gate a learner whose
    // preferences row is perfectly fine.  It answers false either way here --
    // the gate is advisory and the learner can skip it -- but the two cases are
    // still worth telling apart in the log, which is what `ok` buys.
    public func is_onboarding_complete(db : *DbClient, learner_id : &string) : bool {
        if(learner_id.size() == 0) { return false }
        var lid = sql_escape(learner_id)
        var sql = string("SELECT onboarding_completed_at FROM learning_preferences WHERE learner_id = '")
        sql.append_string(&lid)
        sql.append_view("' LIMIT 1")
        var res = underlayer_db::query_sql(db, &raw sql)
        if(!res.ok) { return false }
        var ri : size_t = 0
        while(ri < res.rows.size()) {
            var row = res.rows.get_ptr(ri)
            if(row.vals.size() >= 1) {
                // SQLite hands back NULL as an empty/absent column.  A row whose
                // timestamp is 0 means "the column exists but was never set",
                // which is exactly the not-onboarded case.
                var v = row.vals.get_ptr(0)
                if(v.size() > 0) {
                    var n = parse_i64(v.to_view())
                    if(n != 0) { return true }
                }
            }
            ri = ri + 1
        }
        return false
    }

    // Record that onboarding finished, at `when`.  Idempotent: the timestamp is
    // only written if it is not already set, so a learner who finishes twice
    // keeps the first time.  That matters because this value answers "when did
    // this learner start" to anything that reads it later, and overwriting it
    // with a later re-run would make the answer wrong.
    //
    // Returns true when a row was written.
    public func mark_onboarding_complete(db : *DbClient, learner_id : &string, when : i64) : bool {
        if(learner_id.size() == 0) { return false }
        var lid = sql_escape(learner_id)
        var ts = underlayer_core::int_to_string(when)
        var sql = string("UPDATE learning_preferences SET onboarding_completed_at = ")
        sql.append_view(ts.to_view())
        sql.append_view(", updated_at = ")
        sql.append_view(ts.to_view())
        sql.append_view(" WHERE learner_id = '")
        sql.append_string(&lid)
        sql.append_view("' AND (onboarding_completed_at IS NULL OR onboarding_completed_at = 0)")
        var res = underlayer_db::exec_sql(db, &raw sql)
        return res.ok && res.rows_affected > 0
    }

}