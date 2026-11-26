// Weakness API endpoint tests
using std::string
using std::string_view
using std::Result
using std::Option

// P2 4.2.16/4.2.17: mistake pattern classification (direct logic test)
@test
public func test_mistake_pattern_classification(env : &mut TestEnv) {
    // Consistent failure: 3 attempts, 0 correct
    var s1 = underlayer_models::ConceptState::make()
    s1.concept_id = string("probe-a")
    s1.attempts = 3
    s1.correct = 0
    var kind1 = underlayer_learning::classify_mistake_pattern(&s1)
    var cf = string("consistent_failure")
    if(!kind1.equals(&cf)) { env.error("expected consistent_failure") }

    // Intermittent: 3 attempts, 1 correct (33%)
    var s2 = underlayer_models::ConceptState::make()
    s2.concept_id = string("probe-b")
    s2.attempts = 3
    s2.correct = 1
    var kind2 = underlayer_learning::classify_mistake_pattern(&s2)
    var it = string("intermittent")
    if(!kind2.equals(&it)) { env.error("expected intermittent") }

    // Streak reset: 4 attempts, 3 correct (75%), streak 0
    var s3 = underlayer_models::ConceptState::make()
    s3.concept_id = string("probe-c")
    s3.attempts = 4
    s3.correct = 3
    s3.streak = 0
    var kind3 = underlayer_learning::classify_mistake_pattern(&s3)
    var sr = string("streak_reset")
    if(!kind3.equals(&sr)) { env.error("expected streak_reset") }

    // Not enough signal: 2 attempts, 0 correct
    var s4 = underlayer_models::ConceptState::make()
    s4.concept_id = string("probe-d")
    s4.attempts = 2
    s4.correct = 0
    var kind4 = underlayer_learning::classify_mistake_pattern(&s4)
    var np = string("no_pattern")
    if(!kind4.equals(&np)) { env.error("expected no_pattern for few attempts") }

    // Healthy: 5 attempts, 5 correct, streak 3
    var s5 = underlayer_models::ConceptState::make()
    s5.concept_id = string("probe-e")
    s5.attempts = 5
    s5.correct = 5
    s5.streak = 3
    var kind5 = underlayer_learning::classify_mistake_pattern(&s5)
    if(!kind5.equals(&np)) { env.error("expected no_pattern for healthy state") }

    // Personalized feedback is non-empty exactly when there is a pattern
    var patterns = std::vector<underlayer_models::ConceptState>()
    patterns.push(s1)
    var detected = underlayer_learning::detect_mistake_patterns(&patterns)
    if(detected.size() != 1) { env.error("expected 1 detected pattern") }
    var p0 = detected.at_ref(0)
    var feedback = underlayer_learning::personalized_feedback(p0)
    if(feedback.size() == 0) { env.error("expected non-empty feedback") }
}

@test
public func test_weakness_dashboard_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19920")
    var srv = server.Server(cfg)
    var dbp73_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/weaknesses", (|dbp73_addr|(req) => {
        var dbp73 : *underlayer_db::DbClient = dbp73_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_weakness_dashboard(dbp73, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19920/api/weaknesses")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_weakness_export_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19921")
    var srv = server.Server(cfg)
    var dbp97_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/weaknesses/export", (|dbp97_addr|(req) => {
        var dbp97 : *underlayer_db::DbClient = dbp97_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_weakness_export(dbp97, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19921/api/weaknesses/export")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_weakness_compare_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19925")
    var srv = server.Server(cfg)
    var dbp120_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/weaknesses/compare", (|dbp120_addr|(req) => {
        var dbp120 : *underlayer_db::DbClient = dbp120_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_weakness_compare(dbp120, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19925/api/weaknesses/compare?concept_id=bytes")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    // Verify real aggregated data fields are present
    if(body.find_or_npos(string_view("anonymous_accuracy")) == std::NPOS) { env.error("missing anonymous_accuracy") }
    if(body.find_or_npos(string_view("anonymous_total_attempts")) == std::NPOS) { env.error("missing anonymous_total_attempts") }
    if(body.find_or_npos(string_view("average_severity")) == std::NPOS) { env.error("missing average_severity") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_weakness_alerts_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19923")
    var srv = server.Server(cfg)
    var dbp150_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/weaknesses/alerts", (|dbp150_addr|(req) => {
        var dbp150 : *underlayer_db::DbClient = dbp150_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_weakness_alerts(dbp150, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19923/api/weaknesses/alerts")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_weakness_dashboard_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19924")
    var srv = server.Server(cfg)
    var dbp174_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/weaknesses", (|dbp174_addr|(req) => {
        var dbp174 : *underlayer_db::DbClient = dbp174_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_weakness_dashboard(dbp174, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19924/api/weaknesses")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unsafe { unreachable }
    if(ct_val.find_or_npos(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}
