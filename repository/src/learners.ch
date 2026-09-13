// underlayer_repository — Learner CRUD.
using std::string
using underlayer_db::DbClient
using underlayer_models::Learner

public namespace underlayer_repository {

    public func create_learner(db : *DbClient, learner_id : &string, name : &string, email : &string) {
        var sql = string("INSERT OR IGNORE INTO learners (id, name, email, created_at) VALUES ('")
        sql.append_string(learner_id)
        sql.append_view("', '")
        sql.append_string(name)
        sql.append_view("', '")
        sql.append_string(email)
        sql.append_view("', ")
        var ts = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        sql.append_view(ts.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_learner(db : *DbClient, learner_id : &string) : Learner {
        var learner = Learner::make()
        var sql = string("SELECT id, name, email, created_at FROM learners WHERE id = '")
        sql.append_string(learner_id)
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
