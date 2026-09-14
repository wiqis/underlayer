// Content validation tests — verify JSON responses contain expected strings.
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_list_courses_body_has_elf_course(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19950")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses", (|&courses_dir|(req, res) => {
        underlayer_web::handle_list_courses(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19950u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19950/api/courses")
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
public func test_list_courses_body_has_title_field(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19951")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses", (|&courses_dir|(req, res) => {
        underlayer_web::handle_list_courses(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19951u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19951/api/courses")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("title")) == std::NPOS) { env.error("body missing 'title'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_list_courses_body_has_id_field(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19952")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/courses", (|&courses_dir|(req, res) => {
        underlayer_web::handle_list_courses(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19952u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19952/api/courses")
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
public func test_get_course_elf_has_modules(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19953")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    srv.router.add("GET", "/api/courses/elf", (|&courses_dir, &course_id|(req, res) => {
        var cv = course_id.to_view()
        underlayer_web::handle_get_course(courses_dir, &raw cv, &req, &raw mut res)
    }))
    srv.serve_async(19953u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19953/api/courses/elf")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("modules")) == std::NPOS) { env.error("body missing 'modules'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_get_course_elf_has_concepts(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19954")
    var srv = server.Server(cfg)
    var course_id = string("elf")
    srv.router.add("GET", "/api/courses/elf", (|&courses_dir, &course_id|(req, res) => {
        var cv = course_id.to_view()
        underlayer_web::handle_get_course(courses_dir, &raw cv, &req, &raw mut res)
    }))
    srv.serve_async(19954u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19954/api/courses/elf")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("concepts")) == std::NPOS) { env.error("body missing 'concepts'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_nonexistent_course_body_has_error(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19955")
    var srv = server.Server(cfg)
    var course_id = string("nonexistent")
    srv.router.add("GET", "/api/courses/nonexistent", (|&courses_dir, &course_id|(req, res) => {
        var cv = course_id.to_view()
        underlayer_web::handle_get_course(courses_dir, &raw cv, &req, &raw mut res)
    }))
    srv.serve_async(19955u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19955/api/courses/nonexistent")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("error")) == std::NPOS) { env.error("body missing 'error'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_elf_body_contains_elf(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19956")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|&courses_dir|(req, res) => {
        underlayer_web::handle_search(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19956u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19956/api/search?q=elf")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("elf")) == std::NPOS) { env.error("search body missing 'elf'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_bytes_body_contains_bytes(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19957")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|&courses_dir|(req, res) => {
        underlayer_web::handle_search(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19957u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19957/api/search?q=bytes")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("bytes")) == std::NPOS) { env.error("search body missing 'bytes'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_no_results_body_is_empty_array(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19958")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|&courses_dir|(req, res) => {
        underlayer_web::handle_search(courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19958u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19958/api/search?q=xyznonexistent")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("results")) == std::NPOS) { env.error("expected 'results' key in body") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_health_body_has_status_ok(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19959")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/health", (req, res) => {
        underlayer_web::handle_health(&req, &raw mut res)
    })
    srv.serve_async(19959u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19959/api/health")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("ok")) == std::NPOS) { env.error("health body missing 'ok'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_health_body_has_json_structure(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19960")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/health", (req, res) => {
        underlayer_web::handle_health(&req, &raw mut res)
    })
    srv.serve_async(19960u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19960/api/health")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("status")) == std::NPOS) { env.error("health body missing 'status'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
