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
    if(body.find(string_view("hat-diagnostic-test")) == std::NPOS) { env.error("manifest missing hat-diagnostic-test") }
    if(body.find(string_view("hat-word-problems")) == std::NPOS) { env.error("manifest missing hat-word-problems") }
    if(body.find(string_view("hat-quadratic-equations")) == std::NPOS) { env.error("manifest missing hat-quadratic-equations") }
    if(body.find(string_view("hat-sets-venn")) == std::NPOS) { env.error("manifest missing hat-sets-venn") }
    if(body.find(string_view("hat-review-method")) == std::NPOS) { env.error("manifest missing hat-review-method") }
    if(body.find(string_view("hat-energy-management")) == std::NPOS) { env.error("manifest missing hat-energy-management") }
    if(body.find(string_view("hat-grouping-puzzles")) == std::NPOS) { env.error("manifest missing hat-grouping-puzzles") }
    if(body.find(string_view("hat-network-routing")) == std::NPOS) { env.error("manifest missing hat-network-routing") }
    if(body.find(string_view("hat-syllogisms")) == std::NPOS) { env.error("manifest missing hat-syllogisms") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_network_routing_lesson_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20117")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-network-routing")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-network-routing", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20117u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20117/api/courses/hat/lessons/hat-network-routing")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Network Routing Sets")) == std::NPOS) { env.error("network lesson missing its title") }
    if(body.find(string_view("One-way circuit")) == std::NPOS) { env.error("network lesson missing the circuit setup") }
    if(body.find(string_view("exactly one intermediary")) == std::NPOS) { env.error("network lesson missing the intermediary quiz") }
    if(body.find(string_view("hat-syllogisms")) == std::NPOS) { env.error("network lesson footer must link next to syllogisms") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_rc_multi_paragraph_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20118")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-reading-comprehension")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-reading-comprehension", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20118u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20118/api/courses/hat/lessons/hat-reading-comprehension")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Multi-paragraph passages change where answers live")) == std::NPOS) { env.error("rc lesson missing multi-paragraph section") }
    if(body.find(string_view("quiz-4")) == std::NPOS) { env.error("rc lesson missing multi-paragraph quiz") }
    if(body.find(string_view("data-answer=\"opening\"")) == std::NPOS) { env.error("rc lesson missing multi-paragraph retrieval blanks") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_geometry_clock_similarity_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20119")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-geometry")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-geometry", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20119u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20119/api/courses/hat/lessons/hat-geometry")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Clock angles")) == std::NPOS) { env.error("geometry lesson missing clock-angle section") }
    if(body.find(string_view("77.5 degrees")) == std::NPOS) { env.error("geometry lesson missing the 2:25 answer") }
    if(body.find(string_view("3 : 4")) == std::NPOS) { env.error("geometry lesson missing similarity altitude ratio") }
    if(body.find(string_view("Exterior angles")) == std::NPOS) { env.error("geometry lesson missing exterior-angle section") }
    if(body.find(string_view("quiz-6")) == std::NPOS) { env.error("geometry lesson missing exterior-angle quiz") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_sequences_ap_inverse_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20120")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-sequences")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-sequences", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20120u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20120/api/courses/hat/lessons/hat-sequences")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("The inverse trick")) == std::NPOS) { env.error("sequences lesson missing AP inverse section") }
    if(body.find(string_view("quiz-5")) == std::NPOS) { env.error("sequences lesson missing AP inverse quiz") }
    if(body.find(string_view("data-answer=\"0\"")) == std::NPOS) { env.error("sequences lesson missing (p+q)th term blank") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_logs_lesson_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20121")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-exponents-roots")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-exponents-roots", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20121u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20121/api/courses/hat/lessons/hat-exponents-roots")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Logarithms are the inverse")) == std::NPOS) { env.error("exponents lesson missing log definition") }
    if(body.find(string_view("Chain (telescoping)")) == std::NPOS) { env.error("exponents lesson missing chain rule") }
    if(body.find(string_view("quiz-6")) == std::NPOS) { env.error("exponents lesson missing log chain quiz") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_algebra_degree_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20122")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-algebra")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-algebra", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20122u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20122/api/courses/hat/lessons/hat-algebra")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Degree of a polynomial")) == std::NPOS) { env.error("algebra lesson missing degree section") }
    if(body.find(string_view("quiz-4")) == std::NPOS) { env.error("algebra lesson missing degree quiz") }
    if(body.find(string_view("data-answer=\"9\"")) == std::NPOS) { env.error("algebra lesson missing degree blank") }
    if(body.find(string_view("Domain and range")) == std::NPOS) { env.error("algebra lesson missing domain-range section") }
    if(body.find(string_view("quiz-6")) == std::NPOS) { env.error("algebra lesson missing range quiz") }
    if(body.find(string_view("data-answer=\"-10\"")) == std::NPOS) { env.error("algebra lesson missing excluded range blank") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_variance_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20123")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-data-probability")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-data-probability", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20123u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20123/api/courses/hat/lessons/hat-data-probability")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Variance and standard deviation")) == std::NPOS) { env.error("data lesson missing variance section") }
    if(body.find(string_view("quiz-4")) == std::NPOS) { env.error("data lesson missing variance quiz") }
    if(body.find(string_view("data-answer=\"8\"")) == std::NPOS) { env.error("data lesson missing variance blank") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_cartesian_product_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20124")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-sets-venn")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-sets-venn", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20124u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20124/api/courses/hat/lessons/hat-sets-venn")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Cartesian product")) == std::NPOS) { env.error("sets lesson missing Cartesian product") }
    if(body.find(string_view("quiz-5")) == std::NPOS) { env.error("sets lesson missing product quiz") }
    if(body.find(string_view("3 &times; 5 = 15")) == std::NPOS) { env.error("sets lesson missing 3x5=15") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_hat_rational_irrational_is_served(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20125")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-number-properties")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-number-properties", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20125u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20125/api/courses/hat/lessons/hat-number-properties")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("Rational vs irrational")) == std::NPOS) { env.error("number lesson missing rational/irrational section") }
    if(body.find(string_view("quiz-8")) == std::NPOS) { env.error("number lesson missing irrational quiz") }
    if(body.find(string_view("data-answer=\"irrational\"")) == std::NPOS) { env.error("number lesson missing irrational blank") }

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
    if(body.find(string_view("division (ladder) method")) == std::NPOS) { env.error("lesson missing the ladder method section") }
    if(body.find(string_view("HCF of 24 and 36")) == std::NPOS) { env.error("lesson missing the HCF quiz") }
    if(body.find(string_view("LCM of 8 and 12")) == std::NPOS) { env.error("lesson missing the LCM quiz") }

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
public func test_hat_diagnostic_test_has_interactive_bank(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20116")
    var srv = server.Server(cfg)
    var course_id = string("hat")
    var concept_id = string("hat-diagnostic-test")
    srv.router.add("GET", "/api/courses/hat/lessons/hat-diagnostic-test", (|&courses_dir, &course_id, &concept_id|(req, res) => {
        var ccv = course_id.to_view()
        var tcv = concept_id.to_view()
        underlayer_web::handle_lesson(courses_dir, &raw ccv, &raw tcv, &req, &raw mut res)
    }))
    srv.serve_async(20116u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:20116/api/courses/hat/lessons/hat-diagnostic-test")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    if(resp.status != 200u) { env.error("expected status 200") }
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("hat-diag-root")) == std::NPOS) { env.error("diagnostic missing its runner root") }
    if(body.find(string_view("HAT_DIAG_QUANT")) == std::NPOS) { env.error("diagnostic missing the quantitative bank") }
    if(body.find(string_view("HAT_DIAG_VERBAL")) == std::NPOS) { env.error("diagnostic missing the verbal bank") }
    if(body.find(string_view("HAT_DIAG_ANALYTICAL")) == std::NPOS) { env.error("diagnostic missing the analytical bank") }
    if(body.find(string_view("hatDiagSubmit")) == std::NPOS) { env.error("diagnostic missing the scoring runner") }
    if(body.find(string_view("Take Your Baseline Diagnostic")) == std::NPOS) { env.error("diagnostic missing its section heading") }

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
