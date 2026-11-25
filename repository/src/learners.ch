// underlayer_repository — Learner CRUD.
//
// WHY create_learner_with_hash() EXISTS ALONGSIDE create_learner().
//
// create_learner() wrote the row WITHOUT password_hash and left the caller to
// fill it with a second UPDATE.  handle_register() did exactly that, and never
// checked whether either statement had worked -- which `underlayer_db::exec_sql`
// actively hides, because it frees SQLite's error message without reporting it.
// So a single apostrophe in a display name ("D'Arcy") produced:
//
//   INSERT INTO learners (... 'D'Arcy' ...)   <- syntax error, silently dropped
//   POST /api/auth/register                   <- answered 200 with a token
//   GET  /api/auth/me                         <- answered 404 "learner not found"
//   POST /api/auth/login                      <- answered 401, forever
//
// The account existed in the client's hands and nowhere else.  One statement
// that writes the hash with the row, and a return value the caller checks,
// makes that class of failure impossible to express.
using std::string
using underlayer_db::DbClient
using underlayer_models::Learner

public namespace underlayer_repository {

    // Insert a learner together with its already-computed password hash, and
    // report whether the row actually landed.  Returns the number of rows the
    // INSERT changed: 1 on success, 0 on any failure.  Every value that came
    // from a request goes through sql_escape() first -- see
    // repository/src/helpers.ch for why concatenating SQL without it is the
    // defect that let a crafted email authenticate as anybody.
    public func create_learner_with_hash(db : *DbClient, learner_id : &string, name : &string, email : &string, password_hash : &string) : i64 {
        var id_s = sql_escape(learner_id)
        var name_s = sql_escape(name)
        var email_s = sql_escape(email)
        var hash_s = sql_escape(password_hash)
        var sql = string("INSERT OR IGNORE INTO learners (id, name, email, password_hash, created_at) VALUES ('")
        sql.append_string(&id_s)
        sql.append_view("', '")
        sql.append_string(&name_s)
        sql.append_view("', '")
        sql.append_string(&email_s)
        sql.append_view("', '")
        sql.append_string(&hash_s)
        sql.append_view("', ")
        var ts = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        sql.append_view(ts.to_view())
        sql.append_view(")")
        var res = underlayer_db::exec_sql(db, &raw sql)
        return res.rows_affected
    }

    // Kept for callers that do not set a password (tests, seeding).  Escapes
    // its inputs; it previously did not, which is why "O'Brien" could not be
    // stored at all.
    public func create_learner(db : *DbClient, learner_id : &string, name : &string, email : &string) {
        var id_s = sql_escape(learner_id)
        var name_s = sql_escape(name)
        var email_s = sql_escape(email)
        var sql = string("INSERT OR IGNORE INTO learners (id, name, email, created_at) VALUES ('")
        sql.append_string(&id_s)
        sql.append_view("', '")
        sql.append_string(&name_s)
        sql.append_view("', '")
        sql.append_string(&email_s)
        sql.append_view("', ")
        var ts = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        sql.append_view(ts.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    // The SHADOW LEARNER for a signed-in Wiqis account.  The account service is
    // the sole source of identity; this row is Underlayer's own place to keep
    // progress, FSRS state and notes.  `account_user_id` is a stable id from
    // the account service — never an email, which the user can change.
    //
    // Find-or-create rather than create-on-every-login, and keyed on that id
    // rather than on a session token: the same account on a phone and in a
    // browser must resolve to ONE local learner.  A synthetic email avoids a
    // UNIQUE collision with a learner created by the legacy local API, and
    // keeps the account's email out of a database that is not its own.
    //
    // The UNIQUE index in schema.ch makes concurrent first logins safe: a
    // losing INSERT is ignored and the row is read back instead of returned
    // as a half-created id.
    public func find_or_create_shadow_learner(db : *DbClient, account_user_id : &string, display_name : &string) : string {
        var aid_s = sql_escape(account_user_id)
        var select_sql = string("SELECT id FROM learners WHERE account_user_id = '")
        select_sql.append_string(&aid_s)
        select_sql.append_view("' LIMIT 1")
        var existing = underlayer_db::query_sql(db, &raw select_sql)
        if(existing.ok && existing.rows.size() > 0) {
            var row = existing.rows.at_ref(0)
            if(row.vals.size() > 0) { return row.vals.at_ref(0).copy() }
        }

        var learner_id = underlayer_core::random_hex(16)
        var name = display_name.copy()
        if(name.empty()) { name = string("Wiqis learner") }
        var name_s = sql_escape(&name)
        var synthetic_email = string("account-")
        synthetic_email.append_string(account_user_id)
        synthetic_email.append_view("@shadow.local")
        var email_s = sql_escape(&synthetic_email)
        var id_s = sql_escape(&learner_id)
        var now = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var sql = string("INSERT OR IGNORE INTO learners (id, name, email, account_user_id, created_at) VALUES ('")
        sql.append_string(&id_s)
        sql.append_view("', '")
        sql.append_string(&name_s)
        sql.append_view("', '")
        sql.append_string(&email_s)
        sql.append_view("', '")
        sql.append_string(&aid_s)
        sql.append_view("', ")
        sql.append_view(now.to_view())
        sql.append_view(")")
        var written = underlayer_db::exec_sql(db, &raw sql)
        if(written.rows_affected == 0) {
            // Another request won the race (or the insert was otherwise
            // refused).  Re-read rather than returning an id with no row.
            var again = underlayer_db::query_sql(db, &raw select_sql)
            if(again.ok && again.rows.size() > 0) {
                var r = again.rows.at_ref(0)
                if(r.vals.size() > 0) { return r.vals.at_ref(0).copy() }
            }
            return string()
        }
        // The same support rows handle_register creates, so onboarding and
        // settings do not read NULL for a brand-new shadow learner.
        var prof_sql = string("INSERT OR IGNORE INTO learner_profiles (learner_id, display_name, username, created_at, updated_at) VALUES ('")
        prof_sql.append_string(&id_s)
        prof_sql.append_view("', '")
        prof_sql.append_string(&name_s)
        prof_sql.append_view("', '', ")
        prof_sql.append_view(now.to_view())
        prof_sql.append_view(", ")
        prof_sql.append_view(now.to_view())
        prof_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw prof_sql)
        var set_sql = string("INSERT OR IGNORE INTO learner_settings (learner_id, created_at, updated_at) VALUES ('")
        set_sql.append_string(&id_s)
        set_sql.append_view("', ")
        set_sql.append_view(now.to_view())
        set_sql.append_view(", ")
        set_sql.append_view(now.to_view())
        set_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw set_sql)
        var pref_sql = string("INSERT OR IGNORE INTO learning_preferences (learner_id, created_at, updated_at) VALUES ('")
        pref_sql.append_string(&id_s)
        pref_sql.append_view("', ")
        pref_sql.append_view(now.to_view())
        pref_sql.append_view(", ")
        pref_sql.append_view(now.to_view())
        pref_sql.append_view(")")
        underlayer_db::exec_sql(db, &raw pref_sql)
        return learner_id
    }

    public func get_learner(db : *DbClient, learner_id : &string) : Learner {
        var learner = Learner::make()
        var id_s = sql_escape(learner_id)
        var sql = string("SELECT id, name, email, created_at FROM learners WHERE id = '")
        sql.append_string(&id_s)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.at_ref(0)
            if(row.vals.size() >= 4) {
                learner.id = row.vals.at_ref(0).copy()
                learner.name = row.vals.at_ref(1).copy()
                learner.email = row.vals.at_ref(2).copy()
                learner.created_at = parse_i64(row.vals.at_ref(3).to_view())
            }
        }
        return learner
    }

}