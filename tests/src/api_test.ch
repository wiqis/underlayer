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
    var res = client.get("http://127.0.0.1:19901/api/review/start")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

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
