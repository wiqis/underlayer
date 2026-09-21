// HAT course coverage tests.
//
// The HAT course is the largest course in the platform: 47 concepts across 6
// modules. These tests guard the wiring that makes it reachable — the manifest
// (concepts + modules) and the server's concept router — and the orientation
// lesson's key factual claim that HAT-1 has no technical section.
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_hat_course_api_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20110")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    srv.router.add("GET", "/api/courses/hat", (|&courses_dir, &course_id|(req, res) => {
        var cv = course_id.to_view()
        underlayer_web::handle_get_course(courses_dir, &raw cv, &req, &raw mut res)
    }))
    srv.serve_async(20110u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20110/api/courses/hat")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_course_api_lists_full_manifest(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20111")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    srv.router.add("GET", "/api/courses/hat", (|&courses_dir, &course_id|(req, res) => {
        var cv = course_id.to_view()
        underlayer_web::handle_get_course(courses_dir, &raw cv, &req, &raw mut res)
    }))
    srv.serve_async(20111u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20111/api/courses/hat")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("hat-number-properties")) == std::NPOS) { env.error("manifest missing hat-number-properties") }
    if(body.find(string_view("hat-paragraph-completion")) == std::NPOS) { env.error("manifest missing hat-paragraph-completion") }
    if(body.find(string_view("hat-cause-effect")) == std::NPOS) { env.error("manifest missing hat-cause-effect") }
    if(body.find(string_view("hat-exam-day")) == std::NPOS) { env.error("manifest missing hat-exam-day") }
    if(body.find(string_view("hat-digital-logic")) == std::NPOS) { env.error("manifest missing hat-digital-logic") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_new_lesson_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20112")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-number-properties")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-number-properties", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20112u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20112/api/courses/hat/lessons/hat-number-properties")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Number Properties")) == std::NPOS) { env.error("lesson missing its title") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_exam_day_lesson_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20113")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-exam-day")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-exam-day", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20113u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20113/api/courses/hat/lessons/hat-exam-day")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Exam Day")) == std::NPOS) { env.error("exam-day lesson missing its title") }
    if(body.find(string_view("negative marking")) == std::NPOS) { env.error("exam-day lesson missing the no-negative-marking fact") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_orientation_rejects_technical_section(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20114")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-exam-overview")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-exam-overview", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20114u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20114/api/courses/hat/lessons/hat-exam-overview")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("no technical section")) == std::NPOS) { env.error("orientation lesson must state HAT-1 has no technical section") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_unknown_lesson_returns_404(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20115")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-not-a-real-lesson")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-not-a-real-lesson", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20115u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20115/api/courses/hat/lessons/hat-not-a-real-lesson")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 404u) { env.error("expected 404 for unknown hat lesson") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
