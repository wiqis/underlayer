// HTML page endpoint tests
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_home_page_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19890")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19890/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_is_html(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19891")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19891/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    var has_html = body.find_or_npos(string_view("<html")) != std::NPOS
    var has_doctype = body.find_or_npos(string_view("<!DOCTYPE")) != std::NPOS
    if(!has_html && !has_doctype) { env.error("not HTML") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}



@test
public func test_review_page_renders_session_in_page(env : &mut TestEnv) {
    // 5.1.16: the review page must fetch /api/review/start and render the
    // session in-page, not navigate the browser to the raw JSON endpoint.
    var lit_a = string("./test_review_page.db")
    var db = test_helpers::setup_test_db_path(&lit_a)
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19897")
    var srv = server.Server(cfg)
    var dbp72_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/review", (|dbp72_addr, courses_dir|(req) => {
        var dbp72 : *underlayer_db::DbClient = dbp72_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_review_page(dbp72, &courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    // A SESSION, because /review is behind the sign-in gate now
    // (web/src/pages_auth_gate.ch): every number it shows is the learner's own,
    // so an anonymous request gets the gate page.  This test then asserted
    // things about the GATE -- "missing pauseSession()", "missing
    // /api/session/abort" -- which read exactly like a broken review page and
    // were not one.  A test that fails for a reason unrelated to what it tests
    // is worse than no test, so the session is what makes this test mean what
    // its name says again.
    var learner_id = string("review-page-learner")
    var token = test_helpers::make_session_token(&raw db, &learner_id)

    var client = http::Client()
    var anon_url = string("http://127.0.0.1:19897/review")
    var res = test_helpers::authed_get(&client, &anon_url, &token)
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected 200") }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }

    // The mode cards must call startMode(), which fetches the start endpoint.
    if(body.find_or_npos(string_view("function startMode(")) == std::NPOS) {
        env.error("review page missing startMode()")
    }
    if(body.find_or_npos(string_view("/api/review/start")) == std::NPOS) {
        env.error("review page does not call /api/review/start")
    }
    // The old broken flow navigated the browser to the raw JSON endpoint.
    if(body.find_or_npos(string_view("window.location.href = \"/api/review/start")) != std::NPOS) {
        env.error("review page still navigates to raw /api/review/start JSON")
    }

    // 5.1.18: session controls (pause/resume/abort/undo/skip) must be present
    // and wired to the /api/session/* endpoints.
    if(body.find_or_npos(string_view("function pauseSession(")) == std::NPOS) { env.error("missing pauseSession()") }
    if(body.find_or_npos(string_view("function resumeSession(")) == std::NPOS) { env.error("missing resumeSession()") }
    if(body.find_or_npos(string_view("function abortSession(")) == std::NPOS) { env.error("missing abortSession()") }
    if(body.find_or_npos(string_view("function undoItem(")) == std::NPOS) { env.error("missing undoItem()") }
    if(body.find_or_npos(string_view("function skipItem(")) == std::NPOS) { env.error("missing skipItem()") }
    if(body.find_or_npos(string_view("/api/session/pause")) == std::NPOS) { env.error("missing /api/session/pause") }
    if(body.find_or_npos(string_view("/api/session/resume")) == std::NPOS) { env.error("missing /api/session/resume") }
    if(body.find_or_npos(string_view("/api/session/abort")) == std::NPOS) { env.error("missing /api/session/abort") }
    if(body.find_or_npos(string_view("/api/session/undo")) == std::NPOS) { env.error("missing /api/session/undo") }
    if(body.find_or_npos(string_view("/api/session/skip")) == std::NPOS) { env.error("missing /api/session/skip") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_review_session_end_marks_completed(env : &mut TestEnv) {
    // 5.1.17: starting a session, submitting an item, then calling
    // /api/review/end must mark the session "completed" (it used to stay
    // "active" forever), and the item must be recorded against the session.
    var lit_a = string("./test_review_end.db")
    var db = test_helpers::setup_test_db_path(&lit_a)
    var courses_dir = string("./courses")

    // Engage the concept so seeding produces a review item for this learner.
    var learner_id = string("end-test-learner")
    var course_id = string("elf")
    var concept_id = string("bytes")
    var state = underlayer_models::ConceptState::make()
    state.learner_id = learner_id.copy()
    state.concept_id = concept_id.copy()
    state.course_id = course_id.copy()
    state.attempts = 1
    underlayer_repository::upsert_concept_state(&raw db, &state)
    underlayer_repository::seed_review_items(&raw db, &learner_id, &course_id)

    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19898")
    var srv = server.Server(cfg)
    var dbp153_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/api/review/start", (|dbp153_addr, courses_dir|(req) => {
        var dbp153 : *underlayer_db::DbClient = dbp153_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_review_start(dbp153, &courses_dir, &req))
    }))
    var dbp156_addr : usize = (&raw db) as usize
    srv.router.add("POST", "/api/review/submit", (|dbp156_addr|(req) => {
        var dbp156 : *underlayer_db::DbClient = dbp156_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_review_submit(dbp156, &mut req))
    }))
    // `handle_review_end` takes `&http::Request`, NOT `*mut http::Request`.  This
    // call passed `&mut req` and has been failing to link since the two
    // signatures diverged -- so the test suite has not built, and a suite that
    // does not build is not a suite with "some failing tests", it is no suite.
    //
    // The asymmetry is real and deliberate on the handler side:
    // handle_review_submit takes `*mut Request` because it calls
    // `read_body(&mut req)`, which has to mutate the request to take the
    // body out of it.  handle_review_end reads no body, so it takes a shared
    // reference.  Passing `&raw mut` to the second is not a harmless extra
    // mutability: in a closure over router state it is also the shape the
    // compiler rejects as a mutation of captured state in a safe context, which
    // is why the build error named the *missing argument* rather than the type.
    var dbp172_addr : usize = (&raw db) as usize
    srv.router.add("POST", "/api/review/end", (|dbp172_addr|(req) => {
        var dbp172 : *underlayer_db::DbClient = dbp172_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_review_end(dbp172, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()

    // A REAL SESSION TOKEN, and this is what the test was missing.  5.1.19 made
    // /api/review/start resolve the learner from the bearer token ONLY, so an
    // anonymous call answers 401 -- correctly, because the `demo` fallback it
    // replaced meant anonymous sessions and ratings were written to one shared
    // learner and polluted real progress.  The token is minted through the
    // same hash path the login handler uses, so this is a token the server
    // accepts rather than a hand-rolled fixture.
    var token = test_helpers::make_session_token(&raw db, &learner_id)

    // Start a session for the engaged learner.
    var start_url = string("http://127.0.0.1:19898/api/review/start?course_id=elf&mode=due&count=5")
    var start_res = test_helpers::authed_get(&client, &start_url, &token)
    if(start_res is Result.Err) { env.error("start request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(start_resp) = start_res else unsafe { unreachable }
    var start_body_opt = start_resp.body.text()
    if(start_body_opt is Option.None) { env.error("start no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(start_body) = start_body_opt else unsafe { unreachable }
    if(start_body.find_or_npos(string_view("\"session_id\":\"")) == std::NPOS) {
        env.error("start response missing session_id")
        stop.shutdown(); underlayer_db::close(&raw db); return
    }

    // Extract session_id (between "\"session_id\":\"" and the next quote).
    var sid = string()
    var key = string("\"session_id\":\"")
    var ki = start_body.find_or_npos(key.to_view())
    if(ki != std::NPOS) {
        var start_i = ki + key.size()
        var i = start_i
        while(i < start_body.size() && start_body.at(i) != '"') {
            sid.append(start_body.at(i))
            i = i + 1
        }
    }
    if(sid.size() == 0) { env.error("could not parse session_id"); stop.shutdown(); underlayer_db::close(&raw db); return }

    // Submit a rating for the session (JSON body path).
    var submit_body = string("{\"concept_id\":\"bytes\",\"rating\":3,\"course_id\":\"elf\",\"time_spent\":7,\"session_id\":\"")
    submit_body.append_string(&sid)
    submit_body.append_view("\"}")
    var sbv = submit_body.to_view()
    var submit_url = string("http://127.0.0.1:19898/api/review/submit")
    var sub_res = test_helpers::authed_post(&client, &submit_url, &token, &sbv, "application/json")
    if(sub_res is Result.Err) { env.error("submit failed"); stop.shutdown(); underlayer_db::close(&raw db); return }

    // Before ending, the session is active.
    var status_before = underlayer_repository::get_session_status(&raw db, &sid)
    if(!status_before.equals(string("active"))) {
        env.error("session should be active before end")
    }

    // End the session.
    var end_url = string("http://127.0.0.1:19898/api/review/end?session_id=")
    end_url.append_string(&sid)
    var end_res = test_helpers::authed_post(&client, &end_url, &token, &ebv, "application/json")
    if(end_res is Result.Err) { env.error("end request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }

    // After ending, the session must be completed.
    var status_after = underlayer_repository::get_session_status(&raw db, &sid)
    if(!status_after.equals(string("completed"))) {
        env.error("session should be completed after /api/review/end")
    }

    // The submitted item must be recorded against the session.
    var items = underlayer_repository::get_session_items(&raw db, &sid)
    if(items.size() == 0) { env.error("session item not recorded") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_review_session_controls_change_state(env : &mut TestEnv) {
    // 5.1.18: pause/resume/abort session controls change the session state.
    var lit_a = string("./test_review_controls.db")
    var db = test_helpers::setup_test_db_path(&lit_a)
    var courses_dir = string("./courses")
    var learner_id = string("controls-learner")
    var course_id = string("elf")
    var ctl_sid = string("ctl-session")
    underlayer_repository::create_session(&raw db, &ctl_sid, &learner_id, 1000)

    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19899")
    var srv = server.Server(cfg)
    var dbp268_addr : usize = (&raw db) as usize
    srv.router.add("POST", "/api/session/pause", (|dbp268_addr|(req) => {
        var dbp268 : *underlayer_db::DbClient = dbp268_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_session_pause(dbp268, &req))
    }))
    var dbp271_addr : usize = (&raw db) as usize
    srv.router.add("POST", "/api/session/resume", (|dbp271_addr|(req) => {
        var dbp271 : *underlayer_db::DbClient = dbp271_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_session_resume(dbp271, &req))
    }))
    var dbp274_addr : usize = (&raw db) as usize
    srv.router.add("POST", "/api/session/abort", (|dbp274_addr|(req) => {
        var dbp274 : *underlayer_db::DbClient = dbp274_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_session_abort(dbp274, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()

    // A TOKEN FOR THE LEARNER WHO OWNS ctl-session, because these three
    // endpoints go through require_own_session (web/src/session_guard.ch).
    // An anonymous caller is refused with 403 -- which is the IDOR fix working
    // -- so a test of the PAUSE/RESUME/ABORT behaviour itself has to be the
    // owner.  The refusal is asserted separately, in
    // additional_api_test.ch's five 403 assertions.
    var token = test_helpers::make_session_token(&raw db, &learner_id)

    var pause_url = string("http://127.0.0.1:19899/api/session/pause?session_id=ctl-session")
    var pause_res = test_helpers::authed_post(&client, &pause_url, &token, &ebv, "application/json")
    if(pause_res is Result.Err) { env.error("pause failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    if(!underlayer_repository::get_session_status(&raw db, &ctl_sid).equals(string("paused"))) {
        env.error("pause did not set status paused")
    }

    var resume_url = string("http://127.0.0.1:19899/api/session/resume?session_id=ctl-session")
    var resume_res = test_helpers::authed_post(&client, &resume_url, &token, &ebv, "application/json")
    if(resume_res is Result.Err) { env.error("resume failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    if(!underlayer_repository::get_session_status(&raw db, &ctl_sid).equals(string("active"))) {
        env.error("resume did not set status active")
    }

    var abort_url = string("http://127.0.0.1:19899/api/session/abort?session_id=ctl-session")
    var abort_res = test_helpers::authed_post(&client, &abort_url, &token, &ebv, "application/json")
    if(abort_res is Result.Err) { env.error("abort failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    // abort deletes the session row
    if(underlayer_repository::get_session_status(&raw db, &ctl_sid).size() != 0) {
        env.error("abort did not delete the session")
    }

    stop.shutdown()
    underlayer_db::close(&raw db)
}


@test
public func test_course_landing_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19895")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    // The database is captured too: the course landing page now renders the
    // enrol control server-side, from the session (web/src/enroll_button.ch,
    // P1 7.1.23), so the handler needs a DbClient it did not need before.
    // `&db` and then `&raw dbp`, because a by-reference capture yields
    // `&DbClient` and the handler wants a `*DbClient` it can copy from.
    var dbp333_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/courses/elf", (|dbp333_addr, courses_dir, course_id|(req) => {
        var dbp333 : *underlayer_db::DbClient = dbp333_addr as *underlayer_db::DbClient
        var cv = course_id.to_view()
        // A local copy inside the closure.  A local declared OUTSIDE it is
        // "outside of lambda scope", and the outer `db` itself has been moved by
        // the time the request arrives -- both of which are this codebase's
        // closure rules, not something about this test.
        return underlayer_web::deliver(&req, underlayer_web::handle_course_landing(dbp333, &courses_dir, &cv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19895/courses/elf")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_lesson_page_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19896")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    var concept_id = string("bytes")
    srv.router.add("GET", "/courses/elf/lessons/bytes", (|courses_dir, course_id, concept_id|(req) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_lesson(&courses_dir, &ccv, &tcv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19896/courses/elf/lessons/bytes")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}
