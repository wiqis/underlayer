// underlayer_tests — the account-gated pages REDIRECT a signed-out reader to
// /login and say where they were; and every auth page resets the body margin.
//
// WHY THIS FILE EXISTS.  Six tests were deleted to make room for it.
//
// Until 2026-10-03 `web/src/pages_auth_gate.ch` rendered a sign-in CARD in place,
// and the tests for /dashboard, /review and /progress asserted that a signed-out
// request came back 200 with a <title>. Those assertions were correct about the
// code and wrong about the product: they PINNED a behaviour nobody wanted, so the
// behaviour could not change without the tests being written to argue with it.
//
// A signed-out reader who asked for their review queue got a page titled "Sign in
// to use review sessions", served AT /review. It could not be bookmarked, shared
// or linked to; reopening the link landed on the same dead end. It read as a
// broken feature rather than as a missing account.
//
// The card is gone. These assert what replaced it, which is a stronger set:
//
//   1. the status is 303, not 200 -- so a client that does not follow is never
//      handed a page that looks like the one it asked for;
//   2. a Location header is present -- a 303 with no Location is a dead end;
//   3. Location is `/login?next=<the page they asked for>`, so signing in returns
//      them there rather than to the home page;
//   4. the body leaks NO learner data -- the original reason the gate was
//      server-side, and the one property that had to survive the change;
//   5. the body repeats the link, for a client that does not follow;
//   6. /login itself is NOT gated -- otherwise this is a redirect loop, which is
//      the one way the change could make things worse;
//   7. the auth pages reset the body margin.
//
// Point 6 is load-bearing. A redirect is only safe when the destination does not
// redirect back, and the old file's header argued that /login might. Checked in
// pages_auth.ch: it navigates only on a SUCCESSFUL submit, so an already-signed-in
// visitor sees the form rather than being bounced -- no cycle.
//
// Point 7 is a visible defect, not a hypothetical. These pages are the only ones
// that do NOT render the shared nav, and the nav is where the body reset lives, so
// they inherited the browser's default 8px body margin -- a gutter down both sides,
// and a `min-height: 100vh` page 16px taller than the viewport, so the sign-in card
// scrolled for no reason.
//
// WHY EVERY URL IS A LITERAL.  This compiler does not support string
// concatenation, so `"127.0.0.1:" + u32_to_string(port)` does not compile -- and
// the first version of this file failed to build with "expected the value to have
// primitive type", pointing at the `+` rather than at the real cause. Each test
// therefore owns a fixed port and a literal URL, which is also how every other
// test in this directory is written.
//
// ONE TEST PER PAGE, deliberately: the failure this guards against is per-route.
// A handler that loses its gate check renders a page of zeroes again, and that is
// invisible from any other route.
using std::string
using std::string_view
using std::Result
using std::Option

public namespace underlayer_tests {

    // 1-5. The whole contract, for whichever page `kind` selects.
    // `kind`: 1 = /review, 2 = /progress, 3 = /dashboard, 4 = /health.
    public func assert_gated_page_redirects(
        env : &mut TestEnv,
        kind : i64,
        port : uint,
        url : &string,
        expected : &string) {

        var db = test_helpers::setup_test_db()
        var courses_dir = string("./courses")
        var cfg = server.ServerConfig()
        if(kind == 4) {
            // /health is the fourth gated page. It needs the gate more than the
            // other three: every figure on it is derived from the signed-in
            // learner's own concept_states and goals, so unsigned it would be
            // coverage 0%, depth 0, three retention numbers at 0% -- a page of
            // zeroes that reads as failure at something nobody has started.
            cfg.addr = string("127.0.0.1:19993")
            var srv = server.Server(cfg)
            var dbp79_addr : usize = (&raw db) as usize
            srv.router.add("GET", "/health", (|dbp79_addr, courses_dir|(req) => {
                var dbp79 : *underlayer_db::DbClient = dbp79_addr as *underlayer_db::DbClient
                return underlayer_web::deliver(&req, underlayer_web::handle_knowledge_health_page(dbp79, &courses_dir, &req))
            }))
            var stop = srv.handle()
            srv.serve_async()
            std::concurrent.sleep_ms(200u)
            run_redirect_checks(env, stop, &raw db, url, expected)
            return
        }
        if(kind == 1) {
            cfg.addr = string("127.0.0.1:19990")
            var srv = server.Server(cfg)
            var dbp91_addr : usize = (&raw db) as usize
            srv.router.add("GET", "/review", (|dbp91_addr, courses_dir|(req) => {
                var dbp91 : *underlayer_db::DbClient = dbp91_addr as *underlayer_db::DbClient
                return underlayer_web::deliver(&req, underlayer_web::handle_review_page(dbp91, &courses_dir, &req))
            }))
            var stop = srv.handle()
            srv.serve_async()
            std::concurrent.sleep_ms(200u)
            run_redirect_checks(env, stop, &raw db, url, expected)
            return
        }
        if(kind == 2) {
            cfg.addr = string("127.0.0.1:19991")
            var srv = server.Server(cfg)
            var dbp103_addr : usize = (&raw db) as usize
            srv.router.add("GET", "/progress", (|dbp103_addr, courses_dir|(req) => {
                var dbp103 : *underlayer_db::DbClient = dbp103_addr as *underlayer_db::DbClient
                return underlayer_web::deliver(&req, underlayer_web::handle_progress_page(dbp103, &courses_dir, &req))
            }))
            var stop = srv.handle()
            srv.serve_async()
            std::concurrent.sleep_ms(200u)
            run_redirect_checks(env, stop, &raw db, url, expected)
            return
        }
        cfg.addr = string("127.0.0.1:19992")
        var srv = server.Server(cfg)
        var dbp114_addr : usize = (&raw db) as usize
        srv.router.add("GET", "/dashboard", (|dbp114_addr, courses_dir|(req) => {
            var dbp114 : *underlayer_db::DbClient = dbp114_addr as *underlayer_db::DbClient
            return underlayer_web::deliver(&req, underlayer_web::handle_dashboard(dbp114, &courses_dir, &req))
        }))
        var stop = srv.handle()
        srv.serve_async()
        std::concurrent.sleep_ms(200u)
        run_redirect_checks(env, stop, &raw db, url, expected)
    }

    // Split out because the three routes build their server in three different
    // scopes, and a `srv` declared in one branch cannot be passed to a helper
    // from another. Each branch therefore falls through to this with its own
    // live server.
    public func run_redirect_checks(
        env : &mut TestEnv,
        stop : server.ShutdownHandle,
        db : *underlayer_db::DbClient,
        url : &string,
        expected : &string) {

        var client = http::Client()
        var res = client.get(url.to_view())
        if(res is Result.Err) {
            env.error("request failed")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }
        var Ok(resp) = res else unsafe { unreachable }

        // 1. The status. 200 here means the reader was handed a page that looks
        //    like the one they asked for, which is the bug this replaced.
        if(resp.status != 303u) {
            env.error("a signed-out gated page must answer 303, not 200")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }

        // 2 + 3. The Location, and that it carries the original path.
        var loc_opt = resp.headers.get("Location")
        if(loc_opt is Option.None) {
            env.error("303 with no Location header is a dead end")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }
        var Some(loc) = loc_opt else unsafe { unreachable }
        var want = string("/login?next=")
        want.append_string(expected)
        if(!loc.equals(&want.to_view())) {
            env.error("wrong Location: expected /login?next= plus the original path")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }

        // 4. No learner data. This is why the gate was server-side in the first
        //    place -- a page of zeroes reads as "you are failing at this" -- and
        //    it is the one property that must not be lost by making the gate
        //    smaller.
        var body_opt = resp.body.text()
        if(body_opt is Option.None) {
            env.error("no body")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }
        var Some(body) = body_opt else unsafe { unreachable }
        // Five separate checks rather than a loop over a literal array: the
        // array's element type is not inferrable here, and the first version of
        // this file failed to build with "unresolved child 'size' in parent
        // 'leak'" -- a complaint about the collection, not about the bug being
        // guarded. Five lines that cannot mis-infer beat a loop that has to be
        // reworked.
        var leaked = false
        if(body.find_or_npos(string_view("concepts_total")) != std::NPOS) { leaked = true }
        if(body.find_or_npos(string_view("progress_percentage")) != std::NPOS) { leaked = true }
        if(body.find_or_npos(string_view("mastery")) != std::NPOS) { leaked = true }
        if(body.find_or_npos(string_view("review_due")) != std::NPOS) { leaked = true }
        if(body.find_or_npos(string_view("learner_id")) != std::NPOS) { leaked = true }
        if(leaked) {
            env.error("the redirect body leaks learner data")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }

        // 5. A client that does not follow the redirect still has a link.
        if(body.find_or_npos(string_view("href=\"/login?next=")) == std::NPOS) {
            env.error("the redirect body does not repeat the link")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }

        stop.shutdown()
        underlayer_db::close(db)
    }

    // 6. /login is not gated, and can read `next`. Without either, the redirect
    //    is either a loop or a trip to the home page.
    public func assert_login_is_not_gated(env : &mut TestEnv) {
        var db = test_helpers::setup_test_db()
        var cfg = server.ServerConfig()
        cfg.addr = string("127.0.0.1:19994")
        var srv = server.Server(cfg)
        srv.router.add("GET", "/login", (req) => {
            return underlayer_web::deliver(&req, underlayer_web::handle_login_page(&req))
        })
        var stop = srv.handle()
        srv.serve_async()
        std::concurrent.sleep_ms(200u)

        var client = http::Client()
        var res = client.get("http://127.0.0.1:19994/login")
        if(res is Result.Err) {
            env.error("request failed")
            stop.shutdown()
            underlayer_db::close(&raw db)
            return
        }
        var Ok(resp) = res else unsafe { unreachable }
        if(resp.status == 303u) {
            env.error("/login redirects too -- every gated page points here, so this is a loop")
            stop.shutdown()
            underlayer_db::close(&raw db)
            return
        }
        if(resp.status != 200u) {
            env.error("/login should be reachable signed out")
            stop.shutdown()
            underlayer_db::close(&raw db)
            return
        }

        var body_opt = resp.body.text()
        if(body_opt is Option.None) {
            env.error("no body")
            stop.shutdown()
            underlayer_db::close(&raw db)
            return
        }
        var Some(body) = body_opt else unsafe { unreachable }
        if(body.find_or_npos(string_view("__ulNextPath")) == std::NPOS) {
            env.error("/login cannot read ?next=, so sign-in loses the page")
            stop.shutdown()
            underlayer_db::close(&raw db)
            return
        }

        stop.shutdown()
        underlayer_db::close(&raw db)
    }

    // 7. The body margin.  `kind`: 1 = login, 2 = register, 3 = forgot-password.
    public func assert_body_margin_reset(env : &mut TestEnv, kind : i64) {
        var db = test_helpers::setup_test_db()
        var cfg = server.ServerConfig()

        if(kind == 1) {
            cfg.addr = string("127.0.0.1:19995")
            var srv = server.Server(cfg)
            srv.router.add("GET", "/login", (req) => {
                return underlayer_web::deliver(&req, underlayer_web::handle_login_page(&req))
            })
            var stop = srv.handle()
            srv.serve_async()
            std::concurrent.sleep_ms(200u)
            var u_login = string("http://127.0.0.1:19995/login")
            check_margin(env, stop, &raw db, u_login.copy())
            return
        }
        if(kind == 2) {
            cfg.addr = string("127.0.0.1:19996")
            var srv = server.Server(cfg)
            srv.router.add("GET", "/register", (req) => {
                return underlayer_web::deliver(&req, underlayer_web::handle_register_page(&req))
            })
            var stop = srv.handle()
            srv.serve_async()
            std::concurrent.sleep_ms(200u)
            var u_register = string("http://127.0.0.1:19996/register")
            check_margin(env, stop, &raw db, u_register.copy())
            return
        }
        cfg.addr = string("127.0.0.1:19997")
        var srv = server.Server(cfg)
        srv.router.add("GET", "/forgot-password", (req) => {
            return underlayer_web::deliver(&req, underlayer_web::handle_forgot_password_page(&req))
        })
        var stop = srv.handle()
        srv.serve_async()
        std::concurrent.sleep_ms(200u)
        var u_forgot = string("http://127.0.0.1:19997/forgot-password")
        check_margin(env, stop, &raw db, u_forgot.copy())
    }

    public func check_margin(
        env : &mut TestEnv,
        stop : server.ShutdownHandle,
        db : *underlayer_db::DbClient,
        url : &string) {

        var client = http::Client()
        var res = client.get(url.to_view())
        if(res is Result.Err) {
            env.error("request failed")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }
        var Ok(resp) = res else unsafe { unreachable }
        var body_opt = resp.body.text()
        if(body_opt is Option.None) {
            env.error("no body")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }
        var Some(body) = body_opt else unsafe { unreachable }
        // Both spellings css_cbi is known to emit, because it rewrites the
        // spacing and an earlier version of this assertion matched only the
        // first one -- so all three tests failed against pages that were already
        // correct. `body { margin:0; }` is what it serves today; the unspaced
        // form is what it served before.
        //
        // This IS coupled to css_cbi's formatting, and that coupling is stated
        // rather than hidden. The alternative -- parsing the rule -- is not
        // available here: `string.find` takes one argument and there is no
        // `slice`, so a rule cannot be isolated and inspected on its own.
        //
        // If css_cbi changes its spacing, these three tests fail with a message
        // about the body margin, which is a false alarm and a cheap one. That is
        // the right trade against silently missing a real regression.
        var minified = body.find_or_npos(string_view("body{margin:0}")) != std::NPOS
        var spaced = body.find_or_npos(string_view("body { margin:0; }")) != std::NPOS
        var spaced_src = body.find_or_npos(string_view("body { margin: 0; }")) != std::NPOS
        if(!minified && !spaced && !spaced_src) {
            env.error("the sign-in page does not reset the body margin: the default 8px gutter comes back")
            stop.shutdown()
            underlayer_db::close(db)
            return
        }
        stop.shutdown()
        underlayer_db::close(db)
    }

}

// ---------------------------------------------------------------------------
// The @test entry points. Kept apart from the assertions so the reasoning for
// each check is written once rather than seven times.
// ---------------------------------------------------------------------------

@test
public func test_review_page_redirects_signed_out_reader(env : &mut TestEnv) {
    underlayer_tests::assert_gated_page_redirects(env, 1i64, 19990u, &string("http://127.0.0.1:19990/review"), &string("/review"))
}

@test
public func test_progress_page_redirects_signed_out_reader(env : &mut TestEnv) {
    underlayer_tests::assert_gated_page_redirects(env, 2i64, 19991u, &string("http://127.0.0.1:19991/progress"), &string("/progress"))
}

@test
public func test_dashboard_redirects_signed_out_reader(env : &mut TestEnv) {
    underlayer_tests::assert_gated_page_redirects(env, 3i64, 19992u, &string("http://127.0.0.1:19992/dashboard"), &string("/dashboard"))
}

// /health renders every learner's health score, coverage and goals, so it is
// gated on the same terms as /dashboard. It answers 303 to
// /login?next=/health when there is no session.
@test
public func test_health_page_redirects_signed_out_reader(env : &mut TestEnv) {
    underlayer_tests::assert_gated_page_redirects(env, 4i64, 19993u, &string("http://127.0.0.1:19993/health"), &string("/health"))
}

@test
public func test_login_page_is_not_gated(env : &mut TestEnv) {
    underlayer_tests::assert_login_is_not_gated(env)
}

@test
public func test_login_page_resets_the_body_margin(env : &mut TestEnv) {
    underlayer_tests::assert_body_margin_reset(env, 1i64)
}

@test
public func test_register_page_resets_the_body_margin(env : &mut TestEnv) {
    underlayer_tests::assert_body_margin_reset(env, 2i64)
}

@test
public func test_forgot_password_page_resets_the_body_margin(env : &mut TestEnv) {
    underlayer_tests::assert_body_margin_reset(env, 3i64)
}