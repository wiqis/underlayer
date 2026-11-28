// underlayer_repository — operator identity and the audit trail (H9).
//
// THERE IS STILL NO `role` COLUMN ON `learners`.  An operator is a STABLE
// identity from the shared account (`account_user_id`) or a local learner id,
// named in the `UL_OPERATOR_IDS` secret-store allow-list.  The server resolves
// that identity from the session it already trusts; a client-supplied `is_admin`
// / `role` / `operator` field is never read by any of these functions.
//
// EVERY successful operator action writes one `audit_log` row carrying the
// actor, the action, a request id and the peer address. The two new columns
// (request_id, actor) are added by a conditional migration in
// schema_migrations.ch, so an older database is upgraded on next start.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_repository {

    // Resolve the caller to an allow-listed identity. Returns the matched entry
    // (so the audit trail records exactly what was authorised) or "".
    // Membership uses the constant-time comparison in underlayer_core.
    public func operator_identity(db : *DbClient, learner_id : &string) : string {
        if(learner_id.empty()) { return string() }
        if(underlayer_core::is_operator(learner_id)) { return learner_id.copy() }

        var lid = sql_escape(learner_id)
        var sql = string("SELECT account_user_id, email FROM learners WHERE id = '")
        sql.append_string(&lid)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.at_ref(0)
            if(row.vals.size() >= 1) {
                var account_id = row.vals.at_ref(0).copy()
                if(account_id.size() > 0) {
                    if(underlayer_core::is_operator(&account_id)) { return account_id }
                }
            }
            if(row.vals.size() >= 2) {
                var email = row.vals.at_ref(1).copy()
                if(email.size() > 0) {
                    if(underlayer_core::is_operator(&email)) { return email }
                }
            }
        }
        return string()
    }

    public func write_operator_audit(db : *DbClient, actor : &string, request_id : &string, ip : &string, action : &string, details : &string) {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var a = sql_escape(actor)
        var rid = sql_escape(request_id)
        var peer = sql_escape(ip)
        var act = sql_escape(action)
        var det = sql_escape(details)

        var sql = string("INSERT INTO audit_log (learner_id, action, details, ip_address, created_at, request_id, actor) VALUES ('")
        sql.append_string(&a)
        sql.append_view("', '")
        sql.append_string(&act)
        sql.append_view("', '")
        sql.append_string(&det)
        sql.append_view("', '")
        sql.append_string(&peer)
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(", '")
        sql.append_string(&rid)
        sql.append_view("', '")
        sql.append_string(&a)
        sql.append_view("')")
        underlayer_db::exec_sql(db, &raw sql)
    }

}
