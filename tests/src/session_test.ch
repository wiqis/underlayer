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
    var dbp14_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/sessions", (|dbp14_addr|(req) => {
        var dbp14 : *underlayer_db::DbClient = dbp14_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_session_history(dbp14, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19930/api/sessions")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_history_returns_json_array(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19931")
    var srv = server.Server(cfg)
    var dbp38_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/sessions", (|dbp38_addr|(req) => {
        var dbp38 : *underlayer_db::DbClient = dbp38_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_session_history(dbp38, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19931/api/sessions")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("sessions")) == std::NPOS) { env.error("expected 'sessions' key in body") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_recommendations_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19932")
    var srv = server.Server(cfg)
    var dbp65_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/review/recommendations", (|dbp65_addr|(req) => {
        var dbp65 : *underlayer_db::DbClient = dbp65_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_session_recommendations(dbp65, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19932/api/review/recommendations")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_time_recommendation_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19933")
    var srv = server.Server(cfg)
    var dbp89_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/review/time-recommendation", (|dbp89_addr|(req) => {
        var dbp89 : *underlayer_db::DbClient = dbp89_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_session_time_recommendation(dbp89, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19933/api/review/time-recommendation")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_recent_history_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19934")
    var srv = server.Server(cfg)
    var dbp113_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/recent", (|dbp113_addr|(req) => {
        var dbp113 : *underlayer_db::DbClient = dbp113_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_recent_history(dbp113, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19934/api/recent")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_recent_history_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19935")
    var srv = server.Server(cfg)
    var dbp137_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/recent", (|dbp137_addr|(req) => {
        var dbp137 : *underlayer_db::DbClient = dbp137_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_recent_history(dbp137, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19935/api/recent")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unsafe { unreachable }
    if(ct_val.find_or_npos(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}
