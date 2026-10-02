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

    public func get_learner(db : *DbClient, learner_id : &string) : Learner {
        var learner = Learner::make()
        var id_s = sql_escape(learner_id)
        var sql = string("SELECT id, name, email, created_at FROM learners WHERE id = '")
        sql.append_string(&id_s)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 4) {
                learner.id = row.vals.get_ptr(0).copy()
                learner.name = row.vals.get_ptr(1).copy()
                learner.email = row.vals.get_ptr(2).copy()
                learner.created_at = parse_i64(row.vals.get_ptr(3).to_view())
            }
        }
        return learner
    }

}