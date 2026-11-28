// underlayer_repository — bounded retention sweep (H16).
//
// The startup call is DRY-RUN ONLY: it counts and logs, it never deletes. A
// real sweep needs an explicit apply=true caller (the nightly gate, run against
// a disposable DB). Nothing here opens a database path of its own, and each
// DELETE is bounded to 200 rows per table per invocation so a bad cutoff can
// never empty a table in one pass.
//
// The 152 historical orphan rows in the developer DB are a FOUNDER decision:
// this file does not delete them, and tools/retention_check.py refuses any DB
// whose path is not explicitly marked disposable.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct RetentionCounts {
        var orphan_concept_states : i64
        var orphan_review_items : i64
        var orphan_sessions : i64
        var orphan_unit_progress : i64
        var orphan_attempts : i64
        var expired_reset_tokens : i64
        var expired_verification_tokens : i64
        var expired_sessions : i64
        var aged_login_rows : i64
        var aged_audit_rows : i64
        var applied : bool

        @make
        func make() : RetentionCounts {
            return RetentionCounts {
                orphan_concept_states = 0,
                orphan_review_items = 0,
                orphan_sessions = 0,
                orphan_unit_progress = 0,
                orphan_attempts = 0,
                expired_reset_tokens = 0,
                expired_verification_tokens = 0,
                expired_sessions = 0,
                aged_login_rows = 0,
                aged_audit_rows = 0,
                applied = false
            }
        }
    }

    private func count_rows(db : *DbClient, sql : &string) : i64 {
        var res = underlayer_db::query_sql(db, &raw sql)
        if(res.rows.size() > 0 && res.rows.at_ref(0).vals.size() > 0) {
            return parse_i64(res.rows.at_ref(0).vals.at_ref(0).to_view())
        }
        return 0
    }

    private func orphan_predicate() : string {
        return string("learner_id <> 'demo' AND learner_id NOT IN (SELECT id FROM learners)")
    }

    private func count_orphans(db : *DbClient, table : &string_view) : i64 {
        var pred = orphan_predicate()
        var sql = string("SELECT COUNT(*) FROM ")
        sql.append_view(table)
        sql.append_view(" WHERE ")
        sql.append_view(pred.to_view())
        return count_rows(db, &sql)
    }

    private func bounded_delete(db : *DbClient, table : &string_view, predicate : &string) {
        var sql = string("DELETE FROM ")
        sql.append_view(table)
        sql.append_view(" WHERE rowid IN (SELECT rowid FROM ")
        sql.append_view(table)
        sql.append_view(" WHERE ")
        sql.append_view(predicate.to_view())
        sql.append_view(" LIMIT 200)")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func retention_preview(db : *DbClient) : RetentionCounts {
        var c = RetentionCounts::make()
        var now = underlayer_core::current_timestamp()
        var login_cutoff = underlayer_core::int_to_string(now - (90 * 86400))
        var audit_cutoff = underlayer_core::int_to_string(now - (180 * 86400))
        var now_s = underlayer_core::int_to_string(now)

        var t_cs = string_view("concept_states")
        var t_ri = string_view("review_items")
        var t_se = string_view("sessions")
        var t_cup = string_view("concept_unit_progress")
        var t_ea = string_view("exercise_attempts")
        c.orphan_concept_states = count_orphans(db, &t_cs)
        c.orphan_review_items = count_orphans(db, &t_ri)
        c.orphan_sessions = count_orphans(db, &t_se)
        c.orphan_unit_progress = count_orphans(db, &t_cup)
        c.orphan_attempts = count_orphans(db, &t_ea)

        var sql_reset = string("SELECT COUNT(*) FROM password_reset_tokens WHERE expires_at < ")
        sql_reset.append_view(now_s.to_view())
        c.expired_reset_tokens = count_rows(db, &sql_reset)
        var sql_verify = string("SELECT COUNT(*) FROM email_verification_tokens WHERE expires_at < ")
        sql_verify.append_view(now_s.to_view())
        c.expired_verification_tokens = count_rows(db, &sql_verify)
        var sql_sess = string("SELECT COUNT(*) FROM auth_sessions WHERE expires_at < ")
        sql_sess.append_view(now_s.to_view())
        c.expired_sessions = count_rows(db, &sql_sess)
        var sql_login = string("SELECT COUNT(*) FROM login_history WHERE created_at < ")
        sql_login.append_view(login_cutoff.to_view())
        c.aged_login_rows = count_rows(db, &sql_login)
        var sql_audit = string("SELECT COUNT(*) FROM audit_log WHERE created_at < ")
        sql_audit.append_view(audit_cutoff.to_view())
        c.aged_audit_rows = count_rows(db, &sql_audit)
        return c
    }

    // Always previews. When `apply` is true, deletes at most 200 rows from each
    // affected table. Returns the PREVIEW counts, with applied=true so the log
    // records what was considered, not a post-hoc guess.
    public func run_retention_sweep(db : *DbClient, apply : bool) : RetentionCounts {
        var c = retention_preview(db)
        c.applied = apply
        if(!apply) { return c }

        var pred = orphan_predicate()
        var t_cs = string_view("concept_states")
        var t_ri = string_view("review_items")
        var t_se = string_view("sessions")
        var t_cup = string_view("concept_unit_progress")
        var t_ea = string_view("exercise_attempts")
        bounded_delete(db, &t_cs, &pred)
        bounded_delete(db, &t_ri, &pred)
        bounded_delete(db, &t_se, &pred)
        bounded_delete(db, &t_cup, &pred)
        bounded_delete(db, &t_ea, &pred)

        var now = underlayer_core::current_timestamp()
        var now_s = underlayer_core::int_to_string(now)
        var reset_pred = string("expires_at < ")
        reset_pred.append_view(now_s.to_view())
        var t_reset = string_view("password_reset_tokens")
        var t_verify = string_view("email_verification_tokens")
        var t_auth = string_view("auth_sessions")
        bounded_delete(db, &t_reset, &reset_pred)
        bounded_delete(db, &t_verify, &reset_pred)
        bounded_delete(db, &t_auth, &reset_pred)

        var login_cutoff = underlayer_core::int_to_string(now - (90 * 86400))
        var audit_cutoff = underlayer_core::int_to_string(now - (180 * 86400))
        var login_pred = string("created_at < ")
        login_pred.append_view(login_cutoff.to_view())
        var audit_pred = string("created_at < ")
        audit_pred.append_view(audit_cutoff.to_view())
        var t_login = string_view("login_history")
        var t_audit = string_view("audit_log")
        bounded_delete(db, &t_login, &login_pred)
        bounded_delete(db, &t_audit, &audit_pred)
        return c
    }

    private func append_count(out : &mut string, label : &string_view, value : i64) {
        out.append_view(label)
        var text = underlayer_core::int_to_string(value)
        out.append_view(text.to_view())
    }

    public func retention_log_line(c : &RetentionCounts) : string {
        var line = string("[retention] applied=")
        if(c.applied) { line.append_view(string_view("true")) } else { line.append_view(string_view("false(dry-run)")) }
        append_count(&mut line, string_view(" orphan_cs="), c.orphan_concept_states)
        append_count(&mut line, string_view(" orphan_ri="), c.orphan_review_items)
        append_count(&mut line, string_view(" orphan_sessions="), c.orphan_sessions)
        append_count(&mut line, string_view(" orphan_cup="), c.orphan_unit_progress)
        append_count(&mut line, string_view(" orphan_attempts="), c.orphan_attempts)
        append_count(&mut line, string_view(" expired_reset="), c.expired_reset_tokens)
        append_count(&mut line, string_view(" expired_verify="), c.expired_verification_tokens)
        append_count(&mut line, string_view(" expired_sessions="), c.expired_sessions)
        append_count(&mut line, string_view(" aged_login="), c.aged_login_rows)
        append_count(&mut line, string_view(" aged_audit="), c.aged_audit_rows)
        return line
    }

}
