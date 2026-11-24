// underlayer_repository — unit-level progress sync (S-2).
//
// ALL SQL for the mobile sync endpoint lives here.  The web layer only parses
// JSON and builds responses.
//
// The conflict rule is LAST-WRITE-WINS PER KEY, keyed on `updated_at`:
//
//   key  = (learner_id, course_id, concept_id, unit_id)
//   an incoming change is stored only when its updated_at is STRICTLY NEWER
//   than the stored one.  Equal timestamps are a no-op (deterministic, and
//   makes replay of the same batch idempotent); older timestamps never
//   overwrite newer state.
//
// This table is additive and separate from `concept_states` / `review_items`.
// Nothing here ever touches stability, reps, interval, next_review, attempts,
// correct or streak.  Those remain server-authoritative, written by
// /api/review/submit alone.
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_models::UnitProgress

public namespace underlayer_repository {

    // The stored change for one key.  `updated_at == 0` means "no row".
    public func progress_sync_get(
        db : *DbClient,
        learner_id : &string,
        course_id : &string,
        concept_id : &string,
        unit_id : &string
    ) : UnitProgress {
        var out = UnitProgress::make()
        var lid = sql_escape(learner_id)
        var cid = sql_escape(course_id)
        var coid = sql_escape(concept_id)
        var uid = sql_escape(unit_id)
        var sql = string("SELECT status, step_index, updated_at FROM concept_unit_progress WHERE learner_id = '")
        sql.append_string(&lid)
        sql.append_view("' AND course_id = '")
        sql.append_string(&cid)
        sql.append_view("' AND concept_id = '")
        sql.append_string(&coid)
        sql.append_view("' AND unit_id = '")
        sql.append_string(&uid)
        sql.append_view("' LIMIT 1")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() == 0) { return out }
        var row = result.rows.at_ref(0)
        if(row.vals.size() < 3) { return out }
        out.learner_id = learner_id.copy()
        out.course_id = course_id.copy()
        out.concept_id = concept_id.copy()
        out.unit_id = unit_id.copy()
        out.status = row.vals.at_ref(0).copy()
        out.step_index = parse_i64(row.vals.at_ref(1).to_view())
        out.updated_at = parse_i64(row.vals.at_ref(2).to_view())
        return out
    }

    // Apply one change under the LWW rule above.  Returns true when this change
    // became the stored value, false when the server already held an equal or
    // newer value.  No branch of this function writes any FSRS column.
    public func progress_sync_apply(db : *DbClient, change : &UnitProgress) : bool {
        if(change.unit_id.size() == 0 || change.concept_id.size() == 0 || change.course_id.size() == 0) {
            return false
        }
        var current = progress_sync_get(
            db,
            &change.learner_id,
            &change.course_id,
            &change.concept_id,
            &change.unit_id
        )
        if(current.updated_at >= change.updated_at && current.updated_at > 0) {
            return false
        }
        var lid = sql_escape(&change.learner_id)
        var cid = sql_escape(&change.course_id)
        var coid = sql_escape(&change.concept_id)
        var uid = sql_escape(&change.unit_id)
        var stat = sql_escape(&change.status)
        var sql = string("INSERT OR REPLACE INTO concept_unit_progress (learner_id, course_id, concept_id, unit_id, status, step_index, updated_at) VALUES ('")
        sql.append_string(&lid)
        sql.append_view("', '")
        sql.append_string(&cid)
        sql.append_view("', '")
        sql.append_string(&coid)
        sql.append_view("', '")
        sql.append_string(&uid)
        sql.append_view("', '")
        sql.append_string(&stat)
        sql.append_view("', ")
        var step = underlayer_core::int_to_string(change.step_index)
        sql.append_string(&step)
        sql.append_view(", ")
        var ts = underlayer_core::int_to_string(change.updated_at)
        sql.append_string(&ts)
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return true
    }

    // Every key for this learner whose updated_at is >= since.  `since=0` is
    // the full initial pull; a client stores the last server_now it saw and
    // sends that back for an incremental pull.
    public func progress_sync_since(db : *DbClient, learner_id : &string, since : i64) : vector<UnitProgress> {
        var out = vector<UnitProgress>()
        var lid = sql_escape(learner_id)
        var sql = string("SELECT course_id, concept_id, unit_id, status, step_index, updated_at FROM concept_unit_progress WHERE learner_id = '")
        sql.append_string(&lid)
        sql.append_view("' AND updated_at >= ")
        var since_str = underlayer_core::int_to_string(since)
        sql.append_string(&since_str)
        sql.append_view(" ORDER BY updated_at ASC, course_id ASC, concept_id ASC, unit_id ASC")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.at_ref(ri)
            if(row.vals.size() >= 6) {
                var item = UnitProgress::make()
                item.learner_id = learner_id.copy()
                item.course_id = row.vals.at_ref(0).copy()
                item.concept_id = row.vals.at_ref(1).copy()
                item.unit_id = row.vals.at_ref(2).copy()
                item.status = row.vals.at_ref(3).copy()
                item.step_index = parse_i64(row.vals.at_ref(4).to_view())
                item.updated_at = parse_i64(row.vals.at_ref(5).to_view())
                out.push(item)
            }
            ri = ri + 1
        }
        return out
    }

}
