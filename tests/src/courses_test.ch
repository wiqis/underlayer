// Course API endpoint tests
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_list_courses_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19880")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses", (|courses_dir|(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_list_courses(&courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19880/api/courses")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_list_courses_returns_json_array(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19881")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses", (|courses_dir|(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_list_courses(&courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19881/api/courses")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.size() == 0u || body.at(0) != '[') { env.error("expected JSON array") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_course_elf_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19882")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    srv.router.add("GET", "/api/courses/elf", (|courses_dir, course_id|(req) => {
        var cv = course_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_get_course(&courses_dir, &cv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19882/api/courses/elf")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_course_elf_contains_title(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19883")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    srv.router.add("GET", "/api/courses/elf", (|courses_dir, course_id|(req) => {
        var cv = course_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_get_course(&courses_dir, &cv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19883/api/courses/elf")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("elf")) == std::NPOS) { env.error("body missing 'elf'") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_nonexistent_course_returns_404(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19884")
    var srv = server.Server(cfg)
    var course_id = string("nonexistent")
    srv.router.add("GET", "/api/courses/nonexistent", (|courses_dir, course_id|(req) => {
        var cv = course_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_get_course(&courses_dir, &cv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19884/api/courses/nonexistent")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 404u) { env.error("expected 404") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_lesson_bytes_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19885")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    var concept_id = string("bytes")
    srv.router.add("GET", "/api/courses/elf/lessons/bytes", (|courses_dir, course_id, concept_id|(req) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_lesson(&courses_dir, &ccv, &tcv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19885/api/courses/elf/lessons/bytes")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_nonexistent_lesson_returns_404(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19886")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    var concept_id = string("nonexistent")
    srv.router.add("GET", "/api/courses/elf/lessons/nonexistent", (|courses_dir, course_id, concept_id|(req) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        return underlayer_web::deliver(&req, underlayer_web::handle_lesson(&courses_dir, &ccv, &tcv, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19886/api/courses/elf/lessons/nonexistent")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 404u) { env.error("expected 404") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19887")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|courses_dir|(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_search(&courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19887/api/search?q=bytes")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}
