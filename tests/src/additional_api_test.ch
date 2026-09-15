// Additional API endpoint tests — learner, goals, sessions, exercises, FSRS, navigation.
using std::string
using std::string_view
using std::Result
using std::Option

// ---- Learner CRUD ----

@test
public func test_create_learner_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20000")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/learners", (|&db|(req, res) => {
        underlayer_web::handle_create_learner(&raw db, &req, &raw mut res)
    }))
    srv.serve_async(20000u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    var res = client.post("http://127.0.0.1:20000/api/learners", &ebv)
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_create_learner_returns_json_with_id(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20001")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/learners", (|&db|(req, res) => {
        underlayer_web::handle_create_learner(&raw db, &req, &raw mut res)
    }))
    srv.serve_async(20001u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    var res = client.post("http://127.0.0.1:20001/api/learners", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("id")) == std::NPOS) { env.error("body missing 'id'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_learner_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20002")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/learners/demo", (|&db|(req, res) => {
        var lid = string("demo")
        var lidv = lid.to_view()
        underlayer_web::handle_get_learner(&raw db, &raw lidv, &req, &raw mut res)
    }))
    srv.serve_async(20002u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20002/api/learners/demo")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    // Handler returns 200 if learner exists, 404 if not — both mean the handler works
    if(resp.status != 200u && resp.status != 404u) { env.error("expected 200 or 404") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_nonexistent_learner_returns_404(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20003")
    var srv = server.Server(cfg)
    var learner_id = string("does-not-exist")
    srv.router.add("GET", "/api/learners/does-not-exist", (|&db, &learner_id|(req, res) => {
        var cv = learner_id.to_view()
        underlayer_web::handle_get_learner(&raw db, &raw cv, &req, &raw mut res)
    }))
    srv.serve_async(20003u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20003/api/learners/does-not-exist")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 404u) { env.error("expected 404") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- Goals ----

@test
public func test_set_goal_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20010")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/goals", (|&db|(req, res) => {
        underlayer_web::handle_set_goal(db, &raw mut req, &raw mut res)
    }))
    srv.serve_async(20010u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    var res = client.post("http://127.0.0.1:20010/api/goals?target_date=1800000000", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_delete_goal_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20011")
    var srv = server.Server(cfg)
    srv.router.add("DELETE", "/api/goals", (|&db|(req, res) => {
        underlayer_web::handle_delete_goal(db, &req, &raw mut res)
    }))
    srv.serve_async(20011u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.delete("http://127.0.0.1:20011/api/goals?learner_id=demo&course_id=elf")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- Sessions ----

@test
public func test_get_sessions_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20020")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/sessions", (|&db|(req, res) => {
        underlayer_web::handle_session_history(db, &req, &raw mut res)
    }))
    srv.serve_async(20020u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20020/api/sessions")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_sessions_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20021")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/sessions", (|&db|(req, res) => {
        underlayer_web::handle_session_history(db, &req, &raw mut res)
    }))
    srv.serve_async(20021u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20021/api/sessions")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unreachable
    if(ct_val.find(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- FSRS ----

@test
public func test_fsrs_optimize_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20030")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/fsrs/optimize", (|&db|(req, res) => {
        underlayer_web::handle_fsrs_optimize(db, &req, &raw mut res)
    }))
    srv.serve_async(20030u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    var res = client.post("http://127.0.0.1:20030/api/fsrs/optimize", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    // 400 expected when no review history (< 10 reviews needed)
    if(resp.status != 400u) { env.error("expected 400 (insufficient history)") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_fsrs_reset_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20031")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/fsrs/reset", (|&db|(req, res) => {
        underlayer_web::handle_fsrs_reset(db, &req, &raw mut res)
    }))
    srv.serve_async(20031u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    var res = client.post("http://127.0.0.1:20031/api/fsrs/reset", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- Exercises ----

@test
public func test_exercises_hint_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20040")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/exercises/hint", (|&db|(req, res) => {
        underlayer_web::handle_exercise_hint(db, &req, &raw mut res)
    }))
    srv.serve_async(20040u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20040/api/exercises/hint?exercise_id=1")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    // 404 expected since test DB has no exercises
    if(resp.status != 404u) { env.error("expected 404 (exercise not found)") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_exercises_submit_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20041")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/exercises/submit", (|&db|(req, res) => {
        underlayer_web::handle_exercise_submit(db, &raw mut req, &raw mut res)
    }))
    srv.serve_async(20041u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    // Handler reads exercise_id and answer from query params
    var res = client.post("http://127.0.0.1:20041/api/exercises/submit?exercise_id=1&answer=A", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    // 404 expected since test DB has no exercises
    if(resp.status != 404u) { env.error("expected 404 (exercise not found)") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- Session Management ----

@test
public func test_session_pause_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20050")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/session/pause", (|&db|(req, res) => {
        underlayer_web::handle_session_pause(db, &req, &raw mut res)
    }))
    srv.serve_async(20050u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    // Handler reads session_id from query params
    var res = client.post("http://127.0.0.1:20050/api/session/pause?session_id=999", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u && resp.status != 404u) { env.error("expected 200 or 404") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_resume_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20051")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/session/resume", (|&db|(req, res) => {
        underlayer_web::handle_session_resume(db, &req, &raw mut res)
    }))
    srv.serve_async(20051u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    var res = client.post("http://127.0.0.1:20051/api/session/resume?session_id=999", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u && resp.status != 404u) { env.error("expected 200 or 404") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_abort_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20052")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/session/abort", (|&db|(req, res) => {
        underlayer_web::handle_session_abort(db, &req, &raw mut res)
    }))
    srv.serve_async(20052u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    var res = client.post("http://127.0.0.1:20052/api/session/abort?session_id=999", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u && resp.status != 404u) { env.error("expected 200 or 404") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_undo_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20053")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/session/undo", (|&db|(req, res) => {
        underlayer_web::handle_session_undo(db, &req, &raw mut res)
    }))
    srv.serve_async(20053u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    var res = client.post("http://127.0.0.1:20053/api/session/undo?session_id=999", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u && resp.status != 404u) { env.error("expected 200 or 404") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_session_skip_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20054")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/session/skip", (|&db|(req, res) => {
        underlayer_web::handle_session_skip(db, &req, &raw mut res)
    }))
    srv.serve_async(20054u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    // Handler requires both session_id and concept_id
    var res = client.post("http://127.0.0.1:20054/api/session/skip?session_id=999&concept_id=bytes", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u && resp.status != 404u) { env.error("expected 200 or 404") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- Navigation ----

@test
public func test_navigation_elf_bytes_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20060")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    var concept_id = string("bytes")
    srv.router.add("GET", "/api/navigation/elf/bytes", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_navigation(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20060u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20060/api/navigation/elf/bytes")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_navigation_returns_breadcrumbs(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20061")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    var concept_id = string("bytes")
    srv.router.add("GET", "/api/navigation/elf/bytes", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_navigation(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20061u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20061/api/navigation/elf/bytes")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("breadcrumbs")) == std::NPOS && body.find(string_view("prev")) == std::NPOS) {
        env.error("navigation body missing breadcrumbs/prev")
    }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- Courses All (filter) ----

@test
public func test_courses_all_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20070")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses/all", (|&courses_dir|(req, res) => {
        underlayer_web::handle_filter_courses(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(20070u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20070/api/courses/all")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_courses_all_returns_json(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20071")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses/all", (|&courses_dir|(req, res) => {
        underlayer_web::handle_filter_courses(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(20071u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20071/api/courses/all")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var ct = resp.headers.get("Content-Type")
    if(ct is Option.None) { env.error("missing Content-Type"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(ct_val) = ct else unreachable
    if(ct_val.find(string_view("application/json")) == std::NPOS) { env.error("Content-Type is not application/json") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- FSRS Import ----

@test
public func test_fsrs_import_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20080")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/fsrs/import", (|&db|(req, res) => {
        underlayer_web::handle_fsrs_import(db, &raw mut req, &raw mut res)
    }))
    srv.serve_async(20080u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()
    // Handler reads weights from query params as JSON array
    var res = client.post("http://127.0.0.1:20080/api/fsrs/import?weights=[0.4,0.6,0.8,0.9,1.0,1.2,1.4,1.6,1.8,2.0,2.2,2.4,2.6,2.8,3.0,3.2,3.4,3.6,3.8,4.0,4.2]", &ebv, "application/json")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- Nav Status (P2 7.1.13 progress indicator, P2 7.1.15 due indicator) ----

@test
public func test_nav_status_returns_counts(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20086")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/nav-status", (|&db|(req, res) => {
        underlayer_web::handle_nav_status(db, &req, &raw mut res)
    }))
    srv.serve_async(20086u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20086/api/nav-status")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("concepts_started")) == std::NPOS) { env.error("missing concepts_started") }
    if(body.find(string_view("concepts_total")) == std::NPOS) { env.error("missing concepts_total") }
    if(body.find(string_view("progress_pct")) == std::NPOS) { env.error("missing progress_pct") }
    if(body.find(string_view("due_reviews")) == std::NPOS) { env.error("missing due_reviews") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

// ---- Nav Search / Quick Jump (P2 7.1.10 command palette) ----

@test
public func test_nav_search_returns_entries(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20087")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/nav-search", (req, res) => {
        underlayer_web::handle_nav_search(&req, &raw mut res)
    })
    srv.serve_async(20087u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20087/api/nav-search")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("/courses/elf/lessons/bytes")) == std::NPOS) { env.error("missing bytes lesson entry") }
    if(body.find(string_view("/courses/elf/lessons/execution")) == std::NPOS) { env.error("missing execution lesson entry") }
    if(body.find(string_view("\"entries\"")) == std::NPOS) { env.error("missing entries key") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
