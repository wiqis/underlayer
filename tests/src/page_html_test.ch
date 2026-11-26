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
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19965/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    var has_title = body.find_or_npos(string_view("<title>")) != std::NPOS
    var has_underlayer = body.find_or_npos(string_view("Underlayer")) != std::NPOS
    if(!has_title && !has_underlayer) { env.error("home page missing title or 'Underlayer'") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_doctype(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19966")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19966/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("<!DOCTYPE")) == std::NPOS) { env.error("home page missing <!DOCTYPE") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_nav(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19967")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19967/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("course")) == std::NPOS && body.find_or_npos(string_view("Course")) == std::NPOS) { env.error("home page missing course content") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_links(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19968")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19968/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("href")) == std::NPOS) { env.error("home page missing 'href' links") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_dashboard_page_has_html(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19969")
    var srv = server.Server(cfg)
    var dbp124_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/dashboard", (|dbp124_addr, courses_dir|(req) => {
        var dbp124 : *underlayer_db::DbClient = dbp124_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_dashboard(dbp124, &courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19969/dashboard")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    var has_doctype = body.find_or_npos(string_view("<!DOCTYPE")) != std::NPOS
    var has_html = body.find_or_npos(string_view("<html")) != std::NPOS
    if(!has_doctype && !has_html) { env.error("dashboard page missing HTML structure") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}


@test
public func test_review_page_has_html(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19971")
    var srv = server.Server(cfg)
    var dbp154_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/review", (|dbp154_addr, courses_dir|(req) => {
        var dbp154 : *underlayer_db::DbClient = dbp154_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_review_page(dbp154, &courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19971/review")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    var has_doctype = body.find_or_npos(string_view("<!DOCTYPE")) != std::NPOS
    var has_html = body.find_or_npos(string_view("<html")) != std::NPOS
    if(!has_doctype && !has_html) { env.error("review page missing HTML structure") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}


@test
public func test_progress_page_has_html(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19973")
    var srv = server.Server(cfg)
    var dbp184_addr : usize = (&raw db) as usize
    srv.router.add("GET", "/progress", (|dbp184_addr, courses_dir|(req) => {
        var dbp184 : *underlayer_db::DbClient = dbp184_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_progress_page(dbp184, &courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19973/progress")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    var has_doctype = body.find_or_npos(string_view("<!DOCTYPE")) != std::NPOS
    var has_html = body.find_or_npos(string_view("<html")) != std::NPOS
    if(!has_doctype && !has_html) { env.error("progress page missing HTML structure") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}


@test
public func test_home_page_has_theme_toggle(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19975")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19975/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("theme-toggle")) == std::NPOS) { env.error("home page missing theme-toggle") }
    if(body.find_or_npos(string_view("toggleTheme")) == std::NPOS) { env.error("home page missing toggleTheme JS") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

// This test used to assert `body.find("hamburger") != NPOS`, which passed on the
// DEAD CSS RULE `.hamburger { display: block }` rather than on a button.  There
// has never been a hamburger element in this product's markup, and the six page
// stylesheets that referenced the class hid `.nav-links` outright between 769px
// and 1300px, so on a 1280x800 laptop those pages showed the brand, the theme
// toggle, and no way to reach any other page.  A test that passes on the absence
// of the thing it tests.
//
// It now asserts the parts that have to be true together for a narrow-screen
// menu to work, and each one is checked against the MARKUP or the behaviour
// rather than against a substring that also occurs in a stylesheet:
//
//   1. a real <button> exists, carrying the id the script binds to, an
//      aria-expanded, and an aria-controls naming the panel it opens;
//   2. the panel it controls exists and carries that id;
//   3. the CSS that reveals the panel exists;
//   4. the script that toggles it is on the page;
//   5. /courses is still reachable from the page, so the panel is an addition
//      to the nav and not a replacement for it.
@test
public func test_nav_menu_is_a_real_control(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19976")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19976/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }

    // 1. The whole control, as one literal.  Asserting on the assembled element is
    // what distinguishes "there is a button" from "there is a rule mentioning a
    // class": the string below can only occur if the markup really is a
    // <button> carrying this class, this id, this aria-expanded and this
    // aria-controls.  It is the shape the component emits, so it fails loudly
    // if that shape is ever changed on purpose.
    var btn = string("<button type=\"button\" class=\"nav-toggle\" id=\"ul-nav-toggle\" aria-expanded=\"false\" aria-controls=\"ul-nav-links\">")
    if(body.find_or_npos(btn.to_view()) == std::NPOS) { env.error("nav toggle button missing or malformed"); stop.shutdown(); underlayer_db::close(&raw db); return }

    // 2. The panel it controls must exist, and be the element the script toggles.
    var panel = string("<div class=\"nav-links\" id=\"ul-nav-links\">")
    if(body.find_or_npos(panel.to_view()) == std::NPOS) { env.error("the controlled panel is not on the page"); stop.shutdown(); underlayer_db::close(&raw db); return }

    // 3. + 4. The rule that reveals the panel, and the script that drives it.
    var reveal = string(".nav-links.nav-open")
    if(body.find_or_npos(reveal.to_view()) == std::NPOS) { env.error("no CSS reveals the nav panel"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var toggle_js = string("__ulNavToggle")
    if(body.find_or_npos(toggle_js.to_view()) == std::NPOS) { env.error("no script toggles the nav panel"); stop.shutdown(); underlayer_db::close(&raw db); return }

    // 5. The menu must not be the ONLY way to reach a page.  tools/nav_check.py
    // asserts that separately over all 447 URLs; this is the local check that
    // the panel it counts is a real control rather than a CSS-only ghost.
    var courses = string("href=\"/courses\"")
    if(body.find_or_npos(courses.to_view()) == std::NPOS) { env.error("nav does not link to /courses"); stop.shutdown(); underlayer_db::close(&raw db); return }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

// The SAME control, on a LESSON page -- and that is the assertion that matters.
//
// The toggle script was emitted only on collection pages while the toggle
// BUTTON shipped in the shared markup, so all 398 lesson pages carried a nav
// button wired to nothing. On a phone that button is the only way out of the
// nav, so the failure mode was: narrow a lesson page, tap Menu, nothing happens,
// and the only route left is the browser's back button.
//
// A test on the home page cannot see this, because the home page did get the
// script. The difference between the two call sites is the whole defect.
@test
public func test_lesson_page_nav_menu_works(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19987")
    var srv = server.Server(cfg)
    var courses_dir = string("./courses")
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
    var res = client.get("http://127.0.0.1:19987/courses/elf/lessons/bytes")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }

    // The button is here -- this is the shared markup, unchanged.
    var btn = string("<button type=\"button\" class=\"nav-toggle\" id=\"ul-nav-toggle\" aria-expanded=\"false\" aria-controls=\"ul-nav-links\">")
    if(body.find_or_npos(btn.to_view()) == std::NPOS) { env.error("lesson page has no nav toggle button"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var panel = string("<div class=\"nav-links\" id=\"ul-nav-links\">")
    if(body.find_or_npos(panel.to_view()) == std::NPOS) { env.error("lesson page has no nav panel"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var reveal = string(".nav-links.nav-open")
    if(body.find_or_npos(reveal.to_view()) == std::NPOS) { env.error("lesson page has no CSS revealing the nav panel"); stop.shutdown(); underlayer_db::close(&raw db); return }

    // And now the part that was missing: the script that makes it work.
    var toggle_js = string("__ulNavToggle")
    if(body.find_or_npos(toggle_js.to_view()) == std::NPOS) { env.error("lesson page nav toggle button is dead: no script"); stop.shutdown(); underlayer_db::close(&raw db); return }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

// The nav has to say where the reader is.  Before this the markup hardcoded
// `class="nav-link active"` onto the "Courses" link, so every page in the
// product -- the home page, a lesson, a certificate -- lit up "Courses", and
// the home page lit up a link to a page the reader was not on.  There was never
// a test for the active state, which is why a permanently-wrong value survived.
//
// The assertion is on the MARKUP carrying no hardcoded active class, and on the
// script that decides it being present: the value is computed at runtime from
// `location.pathname`, so the only two things that can be wrong statically are
// "a link is marked active in the HTML" and "nothing ever marks one".
//
// tools/nav_check.py covers the second half across all 447 URLs by checking
// that every href in the nav region resolves.
@test
public func test_nav_marks_the_current_page_at_runtime(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    // 19986, not 19978: `test_home_page_has_search_modal` already holds 19978,
    // and two tests in the same run binding the same port is how that one began
    // failing intermittently -- one of them wins the bind, the other's client
    // reaches the wrong server, and the failure lands on whichever assertion
    // happens to be looking at the response.
    cfg.addr = string("127.0.0.1:19986")
    var srv = server.Server(cfg)
    var courses_dir = string("./courses")
    // `string`, not `string_view`: the handler takes `*string_view`, and a
    // `string_view` built from a literal has no owner to outlive.  The view is
    // taken inside the closure, from the string that does own its bytes -- the
    // same shape `test_navigation_elf_bytes_returns_200` uses.
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
    var res = client.get("http://127.0.0.1:19986/courses/elf/lessons/bytes")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }

    // No link may claim to be the current page in the served HTML.
    var hardcoded = string("nav-link active")
    if(body.find_or_npos(hardcoded.to_view()) != std::NPOS) { env.error("a nav link is hardcoded active in the markup"); stop.shutdown(); underlayer_db::close(&raw db); return }

    // The script that decides it must be there, and it must be the one that
    // reads the path rather than something that hardcodes a key.
    var painter = string("__ulPaintNavActive")
    if(body.find_or_npos(painter.to_view()) == std::NPOS) { env.error("nav active-link script missing"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var reads_path = string("location.pathname")
    if(body.find_or_npos(reads_path.to_view()) == std::NPOS) { env.error("active-link script does not read the current path"); stop.shutdown(); underlayer_db::close(&raw db); return }

    // And it must set aria-current, which is what a screen reader announces.
    var aria = string("aria-current")
    if(body.find_or_npos(aria.to_view()) == std::NPOS) { env.error("active-link script does not set aria-current"); stop.shutdown(); underlayer_db::close(&raw db); return }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_skip_link(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19977")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19977/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("skip-link")) == std::NPOS) { env.error("home page missing skip-link") }
    if(body.find_or_npos(string_view("Skip to content")) == std::NPOS) { env.error("home page missing 'Skip to content' text") }
    if(body.find_or_npos(string_view("focus-visible")) == std::NPOS) { env.error("home page missing focus-visible CSS") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_home_page_has_search_modal(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19978")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    })
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19978/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("search-modal")) == std::NPOS) { env.error("home page missing search-modal") }
    if(body.find_or_npos(string_view("openSearch")) == std::NPOS) { env.error("home page missing openSearch JS") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}
