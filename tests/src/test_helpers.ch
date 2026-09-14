// Test helpers — shared setup code for tests.
// Route registration is inlined in each test because closures need to capture
// stack variables by reference (|&var|) — this only works when the variables
// are in the caller's scope, not in a helper function's parameters.
using std::string
using std::string_view
using std::Result
using std::Option

public namespace test_helpers {

    // Setup a test database. Caller must close with underlayer_db::close(&raw db) when done.
    public func setup_test_db() : underlayer_db::DbClient {
        var db_path = string("./test_underlayer_tmp.db")
        var db = underlayer_db::make_client(db_path.copy(), string())
        underlayer_repository::init_schema(&raw db)
        // Clear stale data from previous test runs to avoid UNIQUE constraint conflicts
        var d1 = string("DELETE FROM learners")
        var d2 = string("DELETE FROM concept_states")
        var d3 = string("DELETE FROM review_items")
        var d4 = string("DELETE FROM sessions")
        var d5 = string("DELETE FROM session_items")
        var d6 = string("DELETE FROM exercises")
        var d7 = string("DELETE FROM learning_goals")
        underlayer_db::exec_sql(&raw db, &raw d1)
        underlayer_db::exec_sql(&raw db, &raw d2)
        underlayer_db::exec_sql(&raw db, &raw d3)
        underlayer_db::exec_sql(&raw db, &raw d4)
        underlayer_db::exec_sql(&raw db, &raw d5)
        underlayer_db::exec_sql(&raw db, &raw d6)
        underlayer_db::exec_sql(&raw db, &raw d7)
        return db
    }
}
