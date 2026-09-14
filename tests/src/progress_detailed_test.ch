// Detailed progress API endpoint tests
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_progress_export_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19940")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/progress/export", (|&db|(req, res) => {
        underlayer_web::handle_progress_export(db, &req, &raw mut res)
    }))
    srv.serve_async(19940u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19940/api/progress/export")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_progress_export_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19941")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/progress/export", (|&db|(req, res) => {
        underlayer_web::handle_progress_export(db, &req, &raw mut res)
    }))
    srv.serve_async(19941u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19941/api/progress/export")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unreachable
    if(ct_val.find(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_analytics_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19942")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/analytics/sessions", (|&db|(req, res) => {
        underlayer_web::handle_session_analytics(db, &req, &raw mut res)
    }))
    srv.serve_async(19942u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19942/api/analytics/sessions")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_analytics_returns_json_array(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19943")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/analytics/sessions", (|&db|(req, res) => {
        underlayer_web::handle_session_analytics(db, &req, &raw mut res)
    }))
    srv.serve_async(19943u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19943/api/analytics/sessions")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("total_sessions")) == std::NPOS) { env.error("expected 'total_sessions' in body") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_fsrs_export_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19944")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/fsrs/export", (|&db|(req, res) => {
        underlayer_web::handle_fsrs_export(db, &req, &raw mut res)
    }))
    srv.serve_async(19944u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19944/api/fsrs/export")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_fsrs_export_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19945")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/fsrs/export", (|&db|(req, res) => {
        underlayer_web::handle_fsrs_export(db, &req, &raw mut res)
    }))
    srv.serve_async(19945u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19945/api/fsrs/export")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unreachable
    if(ct_val.find(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
