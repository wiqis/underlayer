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
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19890u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19890/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_is_html(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19891")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19891u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19891/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    var has_html = body.find(string_view("<html")) != std::NPOS
    var has_doctype = body.find(string_view("<!DOCTYPE")) != std::NPOS
    if(!has_html && !has_doctype) { env.error("not HTML") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_dashboard_page_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19892")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/dashboard", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_dashboard(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19892u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19892/dashboard")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_review_page_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19893")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/review", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_page(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19893u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19893/review")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_progress_page_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19894")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/progress", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_progress_page(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19894u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19894/progress")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

    srv.shutdown()
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
    srv.router.add("GET", "/courses/elf", (|&courses_dir, &course_id|(req, res) => {
        var cv = course_id.to_view()
        underlayer_web::handle_course_landing(courses_dir, &raw cv, &req, &raw mut res)
    }))
    srv.serve_async(19895u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19895/courses/elf")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

    srv.shutdown()
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
    srv.router.add("GET", "/courses/elf/lessons/bytes", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(19896u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19896/courses/elf/lessons/bytes")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
