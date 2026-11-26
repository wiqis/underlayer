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
    var dbp14_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/progress/export", (|dbp14_addr|(req) => {
        var dbp14 : *underlayer_db::DbClient = dbp14_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_progress_export(dbp14, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19940/api/progress/export")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_progress_export_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19941")
    var srv = server.Server(cfg)
    var dbp38_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/progress/export", (|dbp38_addr|(req) => {
        var dbp38 : *underlayer_db::DbClient = dbp38_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_progress_export(dbp38, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19941/api/progress/export")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unsafe { unreachable }
    if(ct_val.find_or_npos(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_analytics_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19942")
    var srv = server.Server(cfg)
    var dbp65_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/sessions", (|dbp65_addr|(req) => {
        var dbp65 : *underlayer_db::DbClient = dbp65_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_session_analytics(dbp65, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19942/api/analytics/sessions")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_analytics_returns_json_array(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19943")
    var srv = server.Server(cfg)
    var dbp89_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/sessions", (|dbp89_addr|(req) => {
        var dbp89 : *underlayer_db::DbClient = dbp89_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_session_analytics(dbp89, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19943/api/analytics/sessions")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("total_sessions")) == std::NPOS) { env.error("expected 'total_sessions' in body") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_fsrs_export_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19944")
    var srv = server.Server(cfg)
    var dbp116_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/fsrs/export", (|dbp116_addr|(req) => {
        var dbp116 : *underlayer_db::DbClient = dbp116_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_fsrs_export(dbp116, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19944/api/fsrs/export")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_fsrs_export_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19945")
    var srv = server.Server(cfg)
    var dbp140_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/fsrs/export", (|dbp140_addr|(req) => {
        var dbp140 : *underlayer_db::DbClient = dbp140_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_fsrs_export(dbp140, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19945/api/fsrs/export")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unsafe { unreachable }
    if(ct_val.find_or_npos(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    stop.shutdown()
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
    var dbp169_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/temporal", (|dbp169_addr|(req) => {
        var dbp169 : *underlayer_db::DbClient = dbp169_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_temporal_analytics(dbp169, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20092/api/analytics/temporal")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected 200") }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("by_hour")) == std::NPOS) { env.error("missing by_hour") }
    if(body.find_or_npos(string_view("by_weekday")) == std::NPOS) { env.error("missing by_weekday") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_retention_analytics_returns_rates(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20093")
    var srv = server.Server(cfg)
    var dbp197_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/retention", (|dbp197_addr|(req) => {
        var dbp197 : *underlayer_db::DbClient = dbp197_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_retention_analytics(dbp197, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20093/api/analytics/retention")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("active_days")) == std::NPOS) { env.error("missing active_days") }
    if(body.find_or_npos(string_view("return_rate_pct")) == std::NPOS) { env.error("missing return_rate_pct") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

// P2 6.2.12 regression: a learner with NO sessions must not be handed a
// fabricated "days since last session".
//
// This is the test that makes the fix non-vacuous.  The bug it pins: over an
// empty sessions table MAX(start_time) is SQL NULL, parse_i64 reads NULL as 0,
// and (now - 0)/86400 evaluated to 20729 — so a learner who had just created an
// account was told by the API they had not studied in 56 years, and
// return_rate_pct came back as 0/1 = "you never come back".
//
// The assertion is on the absence of the fabricated number, not merely on the
// presence of a key.  Asserting `"days_since_last_session"` exists would have
// passed on the broken code too, which is exactly the kind of check that
// protects nothing.
@test
public func test_retention_analytics_no_sessions_reports_null_not_a_fake_gap(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20150")
    var srv = server.Server(cfg)
    var dbp237_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/retention", (|dbp237_addr|(req) => {
        var dbp237 : *underlayer_db::DbClient = dbp237_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_retention_analytics(dbp237, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20150/api/analytics/retention")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }

    // No sessions exist for this learner, so the response must say so.
    // NOTE: env.error takes a *char, and string.c_str() is private to std, so
    // these messages are literals -- as they are in every other test here. Each
    // one names its own assertion so a failure still identifies itself.
    if(body.find_or_npos(string_view("\"has_history\":false")) == std::NPOS) {
        env.error("retention: expected has_history:false for a learner with no sessions")
    }
    // The three figures that need a history must be null, not arithmetic on NULL.
    if(body.find_or_npos(string_view("\"days_since_last_session\":null")) == std::NPOS) {
        env.error("retention: expected days_since_last_session:null, not a fabricated gap")
    }
    if(body.find_or_npos(string_view("\"return_rate_pct\":null")) == std::NPOS) {
        env.error("retention: expected return_rate_pct:null for a learner with no sessions")
    }
    if(body.find_or_npos(string_view("\"span_weeks\":null")) == std::NPOS) {
        env.error("retention: expected span_weeks:null for a learner with no sessions")
    }
    // The count of sessions is still a real measurement and must survive.
    if(body.find_or_npos(string_view("\"total_sessions\":0")) == std::NPOS) {
        env.error("retention: expected total_sessions:0 to still be reported")
    }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_dropoff_analytics_returns_items(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20094")
    var srv = server.Server(cfg)
    var dbp284_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/dropoff", (|dbp284_addr|(req) => {
        var dbp284 : *underlayer_db::DbClient = dbp284_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_dropoff_analytics(dbp284, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20094/api/analytics/dropoff")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("count")) == std::NPOS) { env.error("missing count key") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_funnel_analytics_returns_stages(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20095")
    var srv = server.Server(cfg)
    var dbp310_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/funnel", (|dbp310_addr|(req) => {
        var dbp310 : *underlayer_db::DbClient = dbp310_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_funnel_analytics(dbp310, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20095/api/analytics/funnel")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("registered")) == std::NPOS) { env.error("missing registered") }
    if(body.find_or_npos(string_view("concepts_mastered")) == std::NPOS) { env.error("missing concepts_mastered") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_comparative_analytics_returns_percentile(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20096")
    var srv = server.Server(cfg)
    var dbp337_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/comparative", (|dbp337_addr|(req) => {
        var dbp337 : *underlayer_db::DbClient = dbp337_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_comparative_analytics(dbp337, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20096/api/analytics/comparative")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("my_accuracy")) == std::NPOS) { env.error("missing my_accuracy") }
    if(body.find_or_npos(string_view("percentile")) == std::NPOS) { env.error("missing percentile") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_platform_cohorts_devices_return_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20097")
    var srv = server.Server(cfg)
    var dbp364_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/platform", (|dbp364_addr|(req) => {
        var dbp364 : *underlayer_db::DbClient = dbp364_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_platform_analytics(dbp364, &req))
    }))
    var dbp367_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/cohorts", (|dbp367_addr|(req) => {
        var dbp367 : *underlayer_db::DbClient = dbp367_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_cohort_analytics(dbp367, &req))
    }))
    var dbp370_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/analytics/devices", (|dbp370_addr|(req) => {
        var dbp370 : *underlayer_db::DbClient = dbp370_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_device_analytics(dbp370, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res1 = client.get("http://127.0.0.1:20097/api/analytics/platform")
    if(res1 is Result.Err) { env.error("platform request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(r1) = res1 else unsafe { unreachable }
    if(r1.status != 200u) { env.error("platform expected 200") }
    var b1_opt = r1.body.text()
    if(b1_opt is Option.None) { env.error("platform no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(b1) = b1_opt else unsafe { unreachable }
    if(b1.find_or_npos(string_view("total_learners")) == std::NPOS) { env.error("missing total_learners") }

    var res2 = client.get("http://127.0.0.1:20097/api/analytics/cohorts")
    if(res2 is Result.Err) { env.error("cohorts request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(r2) = res2 else unsafe { unreachable }
    if(r2.status != 200u) { env.error("cohorts expected 200") }

    var res3 = client.get("http://127.0.0.1:20097/api/analytics/devices")
    if(res3 is Result.Err) { env.error("devices request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(r3) = res3 else unsafe { unreachable }
    if(r3.status != 200u) { env.error("devices expected 200") }
    var b3_opt = r3.body.text()
    if(b3_opt is Option.None) { env.error("devices no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(b3) = b3_opt else unsafe { unreachable }
    if(b3.find_or_npos(string_view("total_logins")) == std::NPOS) { env.error("missing total_logins") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

// ---- P2 7.2.19/7.2.20/7.3.6/7.3.11: components page ----

@test
public func test_components_page_renders(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20098")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/components", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_components_demo_page(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20098/components")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected 200") }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    // House pattern (see pages_test.ch): assert HTML-ness, not needles —
    // find() on a short needle inside a large body can crash the test runtime.
    var has_html = body.find_or_npos(string_view("<html")) != std::NPOS
    var has_doctype = body.find_or_npos(string_view("<!DOCTYPE")) != std::NPOS
    if(!has_html && !has_doctype) { env.error("not HTML") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}
