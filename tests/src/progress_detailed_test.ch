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

// ---- P2 6.2.x batch: temporal, retention, dropoff, funnel, comparative,
// platform, cohorts, devices ----

@test
public func test_temporal_analytics_returns_buckets(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20092")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/analytics/temporal", (|&db|(req, res) => {
        underlayer_web::handle_temporal_analytics(db, &req, &raw mut res)
    }))
    srv.serve_async(20092u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20092/api/analytics/temporal")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("by_hour")) == std::NPOS) { env.error("missing by_hour") }
    if(body.find(string_view("by_weekday")) == std::NPOS) { env.error("missing by_weekday") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_retention_analytics_returns_rates(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20093")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/analytics/retention", (|&db|(req, res) => {
        underlayer_web::handle_retention_analytics(db, &req, &raw mut res)
    }))
    srv.serve_async(20093u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20093/api/analytics/retention")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("active_days")) == std::NPOS) { env.error("missing active_days") }
    if(body.find(string_view("return_rate_pct")) == std::NPOS) { env.error("missing return_rate_pct") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_dropoff_analytics_returns_items(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20094")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/analytics/dropoff", (|&db|(req, res) => {
        underlayer_web::handle_dropoff_analytics(db, &req, &raw mut res)
    }))
    srv.serve_async(20094u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20094/api/analytics/dropoff")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("count")) == std::NPOS) { env.error("missing count key") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_funnel_analytics_returns_stages(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20095")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/analytics/funnel", (|&db|(req, res) => {
        underlayer_web::handle_funnel_analytics(db, &req, &raw mut res)
    }))
    srv.serve_async(20095u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20095/api/analytics/funnel")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("registered")) == std::NPOS) { env.error("missing registered") }
    if(body.find(string_view("concepts_mastered")) == std::NPOS) { env.error("missing concepts_mastered") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_comparative_analytics_returns_percentile(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20096")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/analytics/comparative", (|&db|(req, res) => {
        underlayer_web::handle_comparative_analytics(db, &req, &raw mut res)
    }))
    srv.serve_async(20096u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20096/api/analytics/comparative")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("my_accuracy")) == std::NPOS) { env.error("missing my_accuracy") }
    if(body.find(string_view("percentile")) == std::NPOS) { env.error("missing percentile") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_platform_cohorts_devices_return_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20097")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/analytics/platform", (|&db|(req, res) => {
        underlayer_web::handle_platform_analytics(db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/analytics/cohorts", (|&db|(req, res) => {
        underlayer_web::handle_cohort_analytics(db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/analytics/devices", (|&db|(req, res) => {
        underlayer_web::handle_device_analytics(db, &req, &raw mut res)
    }))
    srv.serve_async(20097u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res1 = client.get("http://127.0.0.1:20097/api/analytics/platform")
    if(res1 is Result.Err) { env.error("platform request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(r1) = res1 else unreachable
    if(r1.status != 200u) { env.error("platform expected 200") }
    var b1_opt = r1.body.read_to_string()
    if(b1_opt is Option.None) { env.error("platform no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(b1) = b1_opt else unreachable
    if(b1.find(string_view("total_learners")) == std::NPOS) { env.error("missing total_learners") }

    var res2 = client.get("http://127.0.0.1:20097/api/analytics/cohorts")
    if(res2 is Result.Err) { env.error("cohorts request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(r2) = res2 else unreachable
    if(r2.status != 200u) { env.error("cohorts expected 200") }

    var res3 = client.get("http://127.0.0.1:20097/api/analytics/devices")
    if(res3 is Result.Err) { env.error("devices request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(r3) = res3 else unreachable
    if(r3.status != 200u) { env.error("devices expected 200") }
    var b3_opt = r3.body.read_to_string()
    if(b3_opt is Option.None) { env.error("devices no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(b3) = b3_opt else unreachable
    if(b3.find(string_view("total_logins")) == std::NPOS) { env.error("missing total_logins") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- P2 7.2.19/7.2.20/7.3.6/7.3.11: components page ----

@test
public func test_components_page_renders(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20098")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/components", (req, res) => {
        underlayer_web::handle_components_demo_page(&req, &raw mut res)
    })
    srv.serve_async(20098u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20098/components")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    // House pattern (see pages_test.ch): assert HTML-ness, not needles —
    // find() on a short needle inside a large body can crash the test runtime.
    var has_html = body.find(string_view("<html")) != std::NPOS
    var has_doctype = body.find(string_view("<!DOCTYPE")) != std::NPOS
    if(!has_html && !has_doctype) { env.error("not HTML") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
