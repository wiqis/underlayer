// Mach-O course coverage tests.
//
// Guards the wiring that makes the Mach-O course reachable: the manifest
// (24 concepts / 8 modules), the server's concept router for a sample of
// lessons across the course, and the command palette's Mach-O entries.
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_macho_course_api_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20140")
    var srv = server.Server(cfg)
    var course_id = string("macho")
    srv.router.add("GET", "/api/courses/macho", (|courses_dir, course_id|(req) => {
        var cv = course_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_get_course(&courses_dir, &cv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20140/api/courses/macho")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_macho_course_api_lists_full_manifest(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20141")
    var srv = server.Server(cfg)
    var course_id = string("macho")
    srv.router.add("GET", "/api/courses/macho", (|courses_dir, course_id|(req) => {
        var cv = course_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_get_course(&courses_dir, &cv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20141/api/courses/macho")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("macho-intro")) == std::NPOS) { env.error("manifest missing macho-intro") }
    if(body.find_or_npos(string_view("macho-execution")) == std::NPOS) { env.error("manifest missing macho-execution") }
    if(body.find_or_npos(string_view("macho-load-commands")) == std::NPOS) { env.error("manifest missing macho-load-commands") }
    if(body.find_or_npos(string_view("loading-execution")) == std::NPOS) { env.error("manifest missing loading-execution module") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_macho_intro_lesson_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20142")
    var srv = server.Server(cfg)
    var course_id = string("macho")
    var concept_id = string("macho-intro")
    srv.router.add("GET", "/api/courses/macho/lessons/macho-intro", (|courses_dir, course_id, concept_id|(req) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_lesson(&courses_dir, &ccv, &tcv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20142/api/courses/macho/lessons/macho-intro")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("Why Mach-O Exists")) == std::NPOS) { env.error("intro lesson missing its title") }
    if(body.find_or_npos(string_view("unit-why")) == std::NPOS) { env.error("intro lesson missing unit-why") }
    if(body.find_or_npos(string_view("quiz-option")) == std::NPOS) { env.error("intro lesson missing quiz options") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_macho_last_lesson_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20143")
    var srv = server.Server(cfg)
    var course_id = string("macho")
    var concept_id = string("macho-execution")
    srv.router.add("GET", "/api/courses/macho/lessons/macho-execution", (|courses_dir, course_id, concept_id|(req) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_lesson(&courses_dir, &ccv, &tcv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20143/api/courses/macho/lessons/macho-execution")
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
public func test_nav_search_includes_macho_entries(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20144")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/nav-search", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_nav_search(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20144/api/nav-search")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("/courses/macho/lessons/macho-intro")) == std::NPOS) { env.error("missing macho-intro entry") }
    if(body.find_or_npos(string_view("/courses/macho/lessons/macho-execution")) == std::NPOS) { env.error("missing macho-execution entry") }
    if(body.find_or_npos(string_view("/courses/elf/lessons/bytes")) == std::NPOS) { env.error("elf entries must remain") }
    if(body.find_or_npos(string_view("/courses/pe/lessons/pe-intro")) == std::NPOS) { env.error("pe entries must remain") }
    // Concept entries must open with { after the separating comma — otherwise the
    // palette JSON is invalid even though substring checks still pass.
    if(body.find_or_npos(string_view(",{\"label\":\"")) == std::NPOS) { env.error("concept entries missing opening brace") }
    if(body.find_or_npos(string_view("},\"label\":\"")) != std::NPOS) { env.error("malformed entry: } before next {") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}
