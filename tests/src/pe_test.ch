// PE course coverage tests.
//
// Guards the wiring that makes the PE course reachable: the manifest
// (24 concepts / 8 modules), the server's concept router for a sample of
// lessons across the course, and the command palette's PE entries.
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_pe_course_api_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20130")
    var srv = server.Server(cfg)
    var course_id = string("pe")
    srv.router.add("GET", "/api/courses/pe", (|courses_dir, course_id|(req) => {
        var cv = course_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_get_course(&courses_dir, &cv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20130/api/courses/pe")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_pe_course_api_lists_full_manifest(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20131")
    var srv = server.Server(cfg)
    var course_id = string("pe")
    srv.router.add("GET", "/api/courses/pe", (|courses_dir, course_id|(req) => {
        var cv = course_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_get_course(&courses_dir, &cv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20131/api/courses/pe")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("pe-intro")) == std::NPOS) { env.error("manifest missing pe-intro") }
    if(body.find_or_npos(string_view("pe-execution")) == std::NPOS) { env.error("manifest missing pe-execution") }
    if(body.find_or_npos(string_view("pe-imports")) == std::NPOS) { env.error("manifest missing pe-imports") }
    if(body.find_or_npos(string_view("loading-execution")) == std::NPOS) { env.error("manifest missing loading-execution module") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_pe_intro_lesson_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20132")
    var srv = server.Server(cfg)
    var course_id = string("pe")
    var concept_id = string("pe-intro")
    srv.router.add("GET", "/api/courses/pe/lessons/pe-intro", (|courses_dir, course_id, concept_id|(req) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_lesson(&courses_dir, &ccv, &tcv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20132/api/courses/pe/lessons/pe-intro")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("Why the Portable Executable Format Exists")) == std::NPOS) { env.error("intro lesson missing its title") }
    if(body.find_or_npos(string_view("unit-why")) == std::NPOS) { env.error("intro lesson missing unit-why") }
    if(body.find_or_npos(string_view("quiz-option")) == std::NPOS) { env.error("intro lesson missing quiz options") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_pe_last_lesson_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20133")
    var srv = server.Server(cfg)
    var course_id = string("pe")
    var concept_id = string("pe-execution")
    srv.router.add("GET", "/api/courses/pe/lessons/pe-execution", (|courses_dir, course_id, concept_id|(req) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_lesson(&courses_dir, &ccv, &tcv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20133/api/courses/pe/lessons/pe-execution")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("The Startup Sequence")) == std::NPOS) { env.error("execution lesson missing its title") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_nav_search_includes_pe_entries(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20134")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/nav-search", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_nav_search(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20134/api/nav-search")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("/courses/pe/lessons/pe-intro")) == std::NPOS) { env.error("missing pe-intro entry") }
    if(body.find_or_npos(string_view("/courses/pe/lessons/pe-execution")) == std::NPOS) { env.error("missing pe-execution entry") }
    if(body.find_or_npos(string_view("/courses/elf/lessons/bytes")) == std::NPOS) { env.error("elf entries must remain") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}
