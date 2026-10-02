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
        var lit_a = string("./test_underlayer_tmp.db")
        return setup_test_db_path(&lit_a)
    }

    // Isolated DB path — use when tests run in parallel and would otherwise
    // race on shared ./test_underlayer_tmp.db (DELETE FROM exercises wipes peers).
    public func setup_test_db_path(db_path : &string) : underlayer_db::DbClient {
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

    // A REAL session token for `learner_id`, so a test can call an endpoint
    // that requires a bearer token.
    //
    // WHY THIS EXISTS.  Three tests here call /api/review/start, and that
    // endpoint stopped accepting anonymous callers: 5.1.19 made it resolve the
    // learner from the bearer token ONLY, because the old `demo` fallback meant
    // every anonymous review session and every rating was written to one shared
    // learner and polluted real learners' progress.  With the fix in place the
    // three tests answered 401 and had been failing ever since -- but the SUITE
    // did not build at all (see the two link errors the audit recorded), so
    // nobody could see a red test and read what it was telling them.
    //
    // The alternative would have been to hand-roll an INSERT of a token_hash,
    // which is exactly the kind of second implementation that rots: the hash
    // function is `underlayer_web::hash_token`, and a test that computed its
    // own would pass while the real login path broke.  So this calls the same
    // `generate_random_hex` + `hash_token` + expiry arithmetic that
    // `create_session` uses, and the token it returns is a token the server
    // accepts for real.
    public func make_session_token(db : *underlayer_db::DbClient, learner_id : &string) : string {
        var token = underlayer_web::generate_random_hex(64)
        var token_hash = underlayer_web::hash_token(&raw token)
        var session_id = underlayer_web::generate_random_hex(32)
        var now = underlayer_core::current_timestamp()
        var expires_at = now + 2592000
        var expires_str = underlayer_core::int_to_string(expires_at)
        var now_str = underlayer_core::int_to_string(now)
        var lid = underlayer_repository::sql_escape(learner_id)
        var sql = string("INSERT INTO auth_sessions (id, learner_id, token_hash, expires_at, last_active, created_at) VALUES ('")
        sql.append_string(&session_id)
        sql.append_view("', '")
        sql.append_string(&lid)
        sql.append_view("', '")
        sql.append_string(&token_hash)
        sql.append_view("', ")
        sql.append_view(expires_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(", ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
        return token
    }

    // GET with an `Authorization: Bearer <token>` header.
    //
    // `http::Client::get` takes no headers, so a test that needs a session has
    // to build the RequestBuilder itself.  Doing that inline in every test is
    // how the header quietly goes missing from one of them -- and a test that
    // omits it gets a 401 and fails for a reason that has nothing to do with
    // what it is testing, which is the worst kind of failure to debug.
    //
    // Returns the same Result<Response, string> as Client::get, so callers
    // keep the `is Result.Err` / `Ok(resp)` shape they already use.
    public func authed_get(client : &http::Client, url_str : &string, token : &string) : std::Result<http::Response, std::string> {
        var u_opt = http::URL::parse(url_str.to_view())
        if(u_opt is std::Option.None) { return std::Result.Err<http::Response, std::string>(string("invalid URL")) }
        var Some(u) = u_opt else unreachable
        var rb = http::RequestBuilder("GET", std::replace(&mut u, http::URL()))
        rb.timeout(client.default_timeout_secs)
        var auth_value = string("Bearer ")
        auth_value.append_string(token)
        rb.header_view(string_view("Authorization"), &auth_value.to_view())
        return client.request(&rb)
    }

    // POST with the same header.  `content_type` keeps the call sites readable.
    public func authed_post(client : &http::Client, url_str : &string, token : &string, body : &string_view, content_type : *char = "text/plain") : std::Result<http::Response, std::string> {
        var u_opt = http::URL::parse(url_str.to_view())
        if(u_opt is std::Option.None) { return std::Result.Err<http::Response, std::string>(string("invalid URL")) }
        var Some(u) = u_opt else unreachable
        var rb = http::RequestBuilder("POST", std::replace(&mut u, http::URL()))
        rb.set_body(body, content_type)
        rb.timeout(client.default_timeout_secs)
        var auth_value = string("Bearer ")
        auth_value.append_string(token)
        rb.header_view(string_view("Authorization"), &auth_value.to_view())
        return client.request(&rb)
    }
}
