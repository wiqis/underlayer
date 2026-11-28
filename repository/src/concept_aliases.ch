// underlayer_repository — stable concept identity and forward-only migration
// (H13). A concept id is a DISPLAY SLUG, not an identity: renaming it used to
// strand every learner row that referenced it. This file adds a retired-id ->
// successor map and moves learner state forward once, leaving FSRS columns
// byte-for-byte unchanged.
//
// The alias table is the authority. A retired id may be deleted from course
// content only once it resolves through an alias AND no live learner row still
// points at it. `concept_deletion_allowed` is the guard; it is deliberately a
// repository function so no handler can forget to call it.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public func register_concept_alias(db : *DbClient, old_id : &string, new_id : &string, course_id : &string, reason : &string) {
        if(old_id.empty() || new_id.empty()) { return }
        var old = sql_escape(old_id)
        var target = sql_escape(new_id)
        var course = sql_escape(course_id)
        var reason_escaped = sql_escape(reason)
        var now = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var sql = string("INSERT OR REPLACE INTO concept_aliases (old_id, new_id, course_id, reason, created_at) VALUES ('")
        sql.append_string(&old)
        sql.append_view("', '")
        sql.append_string(&target)
        sql.append_view("', '")
        sql.append_string(&course)
        sql.append_view("', '")
        sql.append_string(&reason_escaped)
        sql.append_view("', ")
        sql.append_view(now.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // Follow a chain forward to its final successor (max 16 hops; a longer
    // chain is a manifest authoring error, not a migration). Returns the input
    // unchanged when no alias is registered.
    public func resolve_concept_alias(db : *DbClient, id : &string) : string {
        var current = id.copy()
        var hops = 0
        while(hops < 16) {
            var esc = sql_escape(&current)
            var sql = string("SELECT new_id FROM concept_aliases WHERE old_id = '")
            sql.append_string(&esc)
            sql.append_view("'")
            var res = underlayer_db::query_sql(db, &raw sql)
            if(res.rows.size() == 0) { return current }
            var row = res.rows.at_ref(0)
            if(row.vals.size() == 0) { return current }
            var next = row.vals.at_ref(0).copy()
            if(next.empty() || next.equals(&current)) { return current }
            current = next
            hops = hops + 1
        }
        return current
    }

    // True while any live learner row still references this id directly. A
    // deletion must be refused until an alias exists AND this returns false
    // (i.e. the rows have been migrated forward).
    public func concept_has_live_state(db : *DbClient, concept_id : &string) : bool {
        if(concept_id.empty()) { return true }
        var cid = sql_escape(concept_id)
        var tables = vector<string>()
        tables.push(string("concept_states"))
        tables.push(string("review_items"))
        tables.push(string("concept_unit_progress"))
        tables.push(string("exercise_attempts"))
        var ti : size_t = 0
        while(ti < tables.size()) {
            var t = tables.at_ref(ti)
            var sql = string("SELECT COUNT(*) FROM ")
            sql.append_view(t.to_view())
            sql.append_view(" WHERE concept_id = '")
            sql.append_string(&cid)
            sql.append_view("'")
            var res = underlayer_db::query_sql(db, &raw sql)
            if(res.rows.size() > 0 && res.rows.at_ref(0).vals.size() > 0) {
                if(underlayer_repository::parse_i64(res.rows.at_ref(0).vals.at_ref(0).to_view()) > 0) { return true }
            }
            ti = ti + 1
        }
        return false
    }

    public func concept_deletion_allowed(db : *DbClient, concept_id : &string) : bool {
        if(concept_id.empty()) { return false }
        var successor = resolve_concept_alias(db, concept_id)
        if(successor.equals(concept_id)) { return false }
        return !concept_has_live_state(db, concept_id)
    }

    private func move_concept_column(db : *DbClient, table : &string_view, old_id : &string, new_id : &string, collision_safe : bool) {
        var old = sql_escape(old_id)
        var target = sql_escape(new_id)
        var sql = string("UPDATE ")
        if(collision_safe) { sql.append_view("OR IGNORE ") }
        sql.append_view("")
        sql.append_view(table)
        sql.append_view(" SET concept_id = '")
        sql.append_string(&target)
        sql.append_view("' WHERE concept_id = '")
        sql.append_string(&old)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
        if(collision_safe) {
            // Rows that collided with the successor are duplicates of the same
            // learner's state under a new slug. Forward-only means the successor
            // wins; no FSRS column is written by this migration.
            var del = string("DELETE FROM ")
            del.append_view(table)
            del.append_view(" WHERE concept_id = '")
            del.append_string(&old)
            del.append_view("'")
            underlayer_db::exec_sql(db, &raw del)
        }
    }

    // Migrate every aliased row in the four learner-state tables. Returns the
    // number of alias entries processed (not the number of rows moved).
    public func migrate_concept_rows(db : *DbClient) : int {
        var alias_sql = string("SELECT old_id FROM concept_aliases ORDER BY old_id")
        var res = underlayer_db::query_sql(db, &raw alias_sql)
        var processed = 0
        var i : size_t = 0
        while(i < res.rows.size()) {
            var row = res.rows.at_ref(i)
            if(row.vals.size() > 0) {
                var old_id = row.vals.at_ref(0).copy()
                var new_id = resolve_concept_alias(db, &old_id)
                if(!new_id.equals(&old_id)) {
                    var cs = string_view("concept_states")
                    var ri = string_view("review_items")
                    var cup = string_view("concept_unit_progress")
                    var ea = string_view("exercise_attempts")
                    move_concept_column(db, &cs, &old_id, &new_id, true)
                    move_concept_column(db, &ri, &old_id, &new_id, false)
                    move_concept_column(db, &cup, &old_id, &new_id, true)
                    move_concept_column(db, &ea, &old_id, &new_id, false)
                    processed = processed + 1
                }
            }
            i = i + 1
        }
        return processed
    }

    // Called from manifest load. `root` is the parsed manifest object; a
    // `concept_aliases` array is optional and absent on today's manifests.
    // Registering aliases is idempotent; migration runs every time but is a
    // no-op once no row references a retired id.
    public func apply_manifest_concept_aliases(db : *DbClient, root : &JsonValue, course_id : &string) : int {
        var node = json_get(root, "concept_aliases")
        if(node is std::Option.None) { return 0 }
        var Some(arr) = node else unsafe { unreachable }
        var n = json_len(arr)
        var i : size_t = 0
        while(i < n) {
            var entry = json_at(arr, i)
            if(entry is std::Option.Some) {
                var Some(val) = entry else unsafe { unreachable }
                var from = json_get_str(val, "from")
                var to = json_get_str(val, "to")
                var why = json_get_str(val, "reason")
                if(from.size() > 0 && to.size() > 0) {
                    register_concept_alias(db, &from, &to, course_id, &why)
                }
            }
            i = i + 1
        }
        return migrate_concept_rows(db)
    }

}
