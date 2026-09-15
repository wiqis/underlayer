// HTML page content validation tests — verify pages contain expected elements.
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_home_page_has_title(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19965")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19965u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19965/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    var has_title = body.find(string_view("<title>")) != std::NPOS
    var has_underlayer = body.find(string_view("Underlayer")) != std::NPOS
    if(!has_title && !has_underlayer) { env.error("home page missing title or 'Underlayer'") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_doctype(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19966")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19966u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19966/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("<!DOCTYPE")) == std::NPOS) { env.error("home page missing <!DOCTYPE") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_nav(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19967")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19967u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19967/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("course")) == std::NPOS && body.find(string_view("Course")) == std::NPOS) { env.error("home page missing course content") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_links(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19968")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19968u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19968/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("href")) == std::NPOS) { env.error("home page missing 'href' links") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_dashboard_page_has_html(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19969")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/dashboard", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_dashboard(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19969u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19969/dashboard")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    var has_doctype = body.find(string_view("<!DOCTYPE")) != std::NPOS
    var has_html = body.find(string_view("<html")) != std::NPOS
    if(!has_doctype && !has_html) { env.error("dashboard page missing HTML structure") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_dashboard_page_has_title(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19970")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/dashboard", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_dashboard(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19970u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19970/dashboard")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("<title>")) == std::NPOS) { env.error("dashboard page missing <title>") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_review_page_has_html(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19971")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/review", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_page(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19971u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19971/review")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    var has_doctype = body.find(string_view("<!DOCTYPE")) != std::NPOS
    var has_html = body.find(string_view("<html")) != std::NPOS
    if(!has_doctype && !has_html) { env.error("review page missing HTML structure") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_review_page_has_title(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19972")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/review", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_page(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19972u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19972/review")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("<title>")) == std::NPOS) { env.error("review page missing <title>") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_progress_page_has_html(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19973")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/progress", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_progress_page(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19973u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19973/progress")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    var has_doctype = body.find(string_view("<!DOCTYPE")) != std::NPOS
    var has_html = body.find(string_view("<html")) != std::NPOS
    if(!has_doctype && !has_html) { env.error("progress page missing HTML structure") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_progress_page_has_title(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19974")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/progress", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_progress_page(db, courses_dir, &req, &raw mut res)
    }))
    srv.serve_async(19974u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19974/progress")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("<title>")) == std::NPOS) { env.error("progress page missing <title>") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_theme_toggle(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19975")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19975u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19975/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("theme-toggle")) == std::NPOS) { env.error("home page missing theme-toggle") }
    if(body.find(string_view("toggleTheme")) == std::NPOS) { env.error("home page missing toggleTheme JS") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_hamburger_menu(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19976")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19976u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19976/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("hamburger")) == std::NPOS) { env.error("home page missing hamburger button") }
    if(body.find(string_view("@media")) == std::NPOS) { env.error("home page missing @media responsive CSS") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_skip_link(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19977")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19977u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19977/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("skip-link")) == std::NPOS) { env.error("home page missing skip-link") }
    if(body.find(string_view("Skip to content")) == std::NPOS) { env.error("home page missing 'Skip to content' text") }
    if(body.find(string_view("focus-visible")) == std::NPOS) { env.error("home page missing focus-visible CSS") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_search_modal(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19978")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })
    srv.serve_async(19978u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19978/")
    if(res is Result.Err) { env.error("request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unreachable
    var body_opt = resp.body.read_to_string()
    if(body_opt is Option.None) { env.error("no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unreachable
    if(body.find(string_view("search-modal")) == std::NPOS) { env.error("home page missing search-modal") }
    if(body.find(string_view("openSearch")) == std::NPOS) { env.error("home page missing openSearch JS") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}
