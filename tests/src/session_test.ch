// Session and review history endpoint tests
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_session_history_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19930")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/sessions", (|&db|(req, res) => {
        underlayer_web::handle_session_history(db, &req, &raw mut res)
    }))
    srv.serve_async(19930u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19930/api/sessions")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_history_returns_json_array(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19931")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/sessions", (|&db|(req, res) => {
        underlayer_web::handle_session_history(db, &req, &raw mut res)
    }))
    srv.serve_async(19931u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19931/api/sessions")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("sessions")) == std::NPOS) { env.error("expected 'sessions' key in body") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_recommendations_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19932")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/review/recommendations", (|&db|(req, res) => {
        underlayer_web::handle_session_recommendations(db, &req, &raw mut res)
    }))
    srv.serve_async(19932u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19932/api/review/recommendations")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_time_recommendation_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19933")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/review/time-recommendation", (|&db|(req, res) => {
        underlayer_web::handle_session_time_recommendation(db, &req, &raw mut res)
    }))
    srv.serve_async(19933u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19933/api/review/time-recommendation")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_recent_history_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19934")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/recent", (|&db|(req, res) => {
        underlayer_web::handle_recent_history(db, &req, &raw mut res)
    }))
    srv.serve_async(19934u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19934/api/recent")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_recent_history_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19935")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/recent", (|&db|(req, res) => {
        underlayer_web::handle_recent_history(db, &req, &raw mut res)
    }))
    srv.serve_async(19935u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19935/api/recent")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unreachable
    if(ct_val.find(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
