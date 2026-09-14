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
    srv.router.add("GET", "/api/courses", (|&courses_dir|(req, res) => {
        underlayer_web::handle_list_courses(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19880u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19880/api/courses")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_list_courses_returns_json_array(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19881")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses", (|&courses_dir|(req, res) => {
        underlayer_web::handle_list_courses(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19881u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19881/api/courses")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.size() == 0u || body.get(0) != '[') { env.error("expected JSON array") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_course_elf_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19882")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses/:courseId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2)
            underlayer_web::handle_get_course(courses_dir, course_id, &req, &raw mut res)
        }
    }))
    srv.serve_async(19882u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19882/api/courses/elf")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_course_elf_contains_title(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19883")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses/:courseId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2)
            underlayer_web::handle_get_course(courses_dir, course_id, &req, &raw mut res)
        }
    }))
    srv.serve_async(19883u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19883/api/courses/elf")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("elf")) == std::NPOS) { env.error("body missing 'elf'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_nonexistent_course_returns_404(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19884")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses/:courseId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2)
            underlayer_web::handle_get_course(courses_dir, course_id, &req, &raw mut res)
        }
    }))
    srv.serve_async(19884u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19884/api/courses/nonexistent")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 404u) { env.error("expected 404") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_lesson_bytes_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19885")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses/:courseId/lessons/:conceptId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.get_ptr(1)
            var concept_id = segments.get_ptr(3)
            underlayer_web::handle_lesson(courses_dir, course_id, concept_id, &req, &raw mut res)
        }
    }))
    srv.serve_async(19885u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19885/api/courses/elf/lessons/bytes")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_nonexistent_lesson_returns_404(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19886")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses/:courseId/lessons/:conceptId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.get_ptr(1)
            var concept_id = segments.get_ptr(3)
            underlayer_web::handle_lesson(courses_dir, course_id, concept_id, &req, &raw mut res)
        }
    }))
    srv.serve_async(19886u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19886/api/courses/elf/lessons/nonexistent")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 404u) { env.error("expected 404") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19887")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|&courses_dir|(req, res) => {
        underlayer_web::handle_search(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19887u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19887/api/search?q=bytes")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
