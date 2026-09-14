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
        return db
    }
}
