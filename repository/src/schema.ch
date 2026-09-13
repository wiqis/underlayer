// underlayer_repository — Schema initialization.
using std::string
using underlayer_db::DbClient

public namespace underlayer_repository {

    public func init_schema(db : *DbClient) {
        var sql = string("CREATE TABLE IF NOT EXISTS learners (id TEXT PRIMARY KEY, name TEXT, email TEXT UNIQUE, created_at INTEGER)")
        underlayer_db::exec_sql(db, &raw sql)
        var sql2 = string("CREATE TABLE IF NOT EXISTS concept_states (learner_id TEXT, concept_id TEXT, course_id TEXT, status TEXT DEFAULT 'not_started', attempts INTEGER DEFAULT 0, correct INTEGER DEFAULT 0, streak INTEGER DEFAULT 0, last_studied INTEGER, next_review INTEGER, difficulty_rating REAL DEFAULT 0, PRIMARY KEY (learner_id, concept_id, course_id))")
        underlayer_db::exec_sql(db, &raw sql2)
        var sql3 = string("CREATE TABLE IF NOT EXISTS review_items (id TEXT PRIMARY KEY, learner_id TEXT, concept_id TEXT, course_id TEXT, type TEXT, front TEXT, back TEXT, difficulty REAL DEFAULT 5.0, stability REAL DEFAULT 1.0, retrievability REAL DEFAULT 1.0, next_review INTEGER, last_review INTEGER, reps INTEGER DEFAULT 0, lapses INTEGER DEFAULT 0)")
        underlayer_db::exec_sql(db, &raw sql3)
        var sql4 = string("CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, learner_id TEXT, start_time INTEGER, end_time INTEGER, type TEXT, exercises_attempted INTEGER DEFAULT 0, exercises_correct INTEGER DEFAULT 0)")
        underlayer_db::exec_sql(db, &raw sql4)
        var idx1 = string("CREATE INDEX IF NOT EXISTS idx_cs_learner ON concept_states(learner_id)")
        underlayer_db::exec_sql(db, &raw idx1)
        var idx2 = string("CREATE INDEX IF NOT EXISTS idx_ri_learner ON review_items(learner_id)")
        underlayer_db::exec_sql(db, &raw idx2)
        var idx3 = string("CREATE INDEX IF NOT EXISTS idx_ri_due ON review_items(next_review)")
        underlayer_db::exec_sql(db, &raw idx3)
        var idx4 = string("CREATE INDEX IF NOT EXISTS idx_sess_learner ON sessions(learner_id)")
        underlayer_db::exec_sql(db, &raw idx4)
    }

}
