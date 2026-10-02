// Progress and Review API endpoint tests
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_progress_api_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19900")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/progress", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_progress(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19900u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19900/api/progress")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_review_start_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19901")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/review/start", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_start(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19901u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()

    // THE ANONYMOUS CALL MUST BE 401, NOT 200.  This test used to assert 200
    // for a request with no Authorization header, which was only ever true
    // because /api/review/start resolved the caller to the shared `demo`
    // learner when no token was present.  5.1.19 removed that fallback --
    // every anonymous review session and every rating was being written to one
    // shared learner, which pollutes real learners' FSRS schedules and streaks.
    // So the 200 case below is now taken WITH a token, and the anonymous case
    // is asserted to be refused.
    //
    // Both halves matter: without the first, this test would pass on a server
    // that rejected every caller; without the second, it would pass on one that
    // accepted every caller.
    var anon_res = client.get("http://127.0.0.1:19901/api/review/start")
    if(anon_res is Result.Err) { env.error("anonymous request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(anon_resp) = anon_res else unreachable
    if(anon_resp.status != 401u) {
        env.error("expected 401 for an anonymous review start, not 200: the shared demo learner must not receive anonymous sessions")
    }

    var learner_id = string("review-start-learner")
    var token = test_helpers::make_session_token(&raw db, &learner_id)
    var url = string("http://127.0.0.1:19901/api/review/start")
    var res = test_helpers::authed_get(&client, &url, &token)
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200 for an authenticated review start") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_review_due_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19902")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/review/due", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_due(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19902u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19902/api/review/due")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19903")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|&courses_dir|(req, res) => {
        underlayer_web::handle_search(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19903u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19903/api/search?q=bytes")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unreachable
    if(ct_val.find(string_view("application/json")) == std::NPOS) { env.error("not JSON") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
