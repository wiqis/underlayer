// Weakness API endpoint tests
using std::string
using std::string_view
using std::Result
using std::Option

// P2 4.2.16/4.2.17: Review submit reports mistake pattern + personalized feedback
@test
public func test_review_submit_mistake_pattern(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20085")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/review/submit", (|&db|(req, res) => {
        underlayer_web::handle_review_submit(db, &raw mut req, &raw mut res)
    }))
    srv.serve_async(20085u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var ebv = std::string_view("")

    // Three failing submissions on the same concept
    var res1 = client.post("http://127.0.0.1:20085/api/review/submit?concept_id=mistake-probe&course_id=elf&rating=again", &ebv, "application/json")
    if(res1 is Result.Err) { env.error("request 1 failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var res2 = client.post("http://127.0.0.1:20085/api/review/submit?concept_id=mistake-probe&course_id=elf&rating=again", &ebv, "application/json")
    if(res2 is Result.Err) { env.error("request 2 failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var res3 = client.post("http://127.0.0.1:20085/api/review/submit?concept_id=mistake-probe&course_id=elf&rating=again", &ebv, "application/json")
    if(res3 is Result.Err) { env.error("request 3 failed"); srv.shutdown(); underlayer_db::close(&raw db); return }

    var Ok(resp3) = res3 else unreachable
    var body_opt = resp3.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable

    // Third failing attempt => consistent_failure pattern with feedback text
    if(body.find(string_view("mistake_pattern")) == std::NPOS) { env.error("missing mistake_pattern key") }
    if(body.find(string_view("consistent_failure")) == std::NPOS) { env.error("expected consistent_failure pattern") }
    if(body.find(string_view("personalized_feedback")) == std::NPOS) { env.error("missing personalized_feedback key") }

    // First submission (fresh state) should not be classified
    var Ok(resp1) = res1 else unreachable
    var body1_opt = resp1.body.read_to_string()
    if(body1_opt is Option.None) { env.error("no body 1"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body1) = body1_opt else unreachable
    if(body1.find(string_view("mistake_pattern\":\"none\"")) == std::NPOS) { env.error("first attempt should be no pattern") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_weakness_dashboard_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19920")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/weaknesses", (|&db|(req, res) => {
        underlayer_web::handle_weakness_dashboard(db, &req, &raw mut res)
    }))
    srv.serve_async(19920u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19920/api/weaknesses")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_weakness_export_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19921")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/weaknesses/export", (|&db|(req, res) => {
        underlayer_web::handle_weakness_export(db, &req, &raw mut res)
    }))
    srv.serve_async(19921u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19921/api/weaknesses/export")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_weakness_compare_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19925")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/weaknesses/compare", (|&db|(req, res) => {
        underlayer_web::handle_weakness_compare(db, &req, &raw mut res)
    }))
    srv.serve_async(19925u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19925/api/weaknesses/compare?concept_id=bytes")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    // Verify real aggregated data fields are present
    if(body.find(string_view("anonymous_accuracy")) == std::NPOS) { env.error("missing anonymous_accuracy") }
    if(body.find(string_view("anonymous_total_attempts")) == std::NPOS) { env.error("missing anonymous_total_attempts") }
    if(body.find(string_view("average_severity")) == std::NPOS) { env.error("missing average_severity") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_weakness_alerts_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19923")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/weaknesses/alerts", (|&db|(req, res) => {
        underlayer_web::handle_weakness_alerts(db, &req, &raw mut res)
    }))
    srv.serve_async(19923u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19923/api/weaknesses/alerts")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_weakness_dashboard_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19924")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/weaknesses", (|&db|(req, res) => {
        underlayer_web::handle_weakness_dashboard(db, &req, &raw mut res)
    }))
    srv.serve_async(19924u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19924/api/weaknesses")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unreachable
    if(ct_val.find(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
