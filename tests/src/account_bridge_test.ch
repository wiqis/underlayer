// Focused tests for the shared-account integration.
//
// NOTE ON THE SUITE (2026-11-25): this application currently stalls in the
// compiler at its last module — a known blocker recorded in AGENTS.md — and the
// pre-existing test sources still use the old ResponseWriter handler shape.
// These cases are written against the CURRENT safe API (handlers return
// http::Response through deliver) so they are ready when that blocker clears;
// they are not patching any library test source.
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_from_account_without_credentials_is_a_clean_401(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19970")
    var srv = server.Server(cfg)
    var dbp20_addr : usize = (&raw db) as usize
    srv.router.add("POST", "/api/auth/from-account", (|dbp20_addr|(req) => {
        var dbp20 : *underlayer_db::DbClient = dbp20_addr as *underlayer_db::DbClient
        return underlayer_web::deliver(&req, underlayer_web::handle_from_account(dbp20, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty = string_view("")
    var res = client.post("http://127.0.0.1:19970/api/auth/from-account", &empty, "application/json")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 401u) { env.error("expected 401 with no account credentials") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_sign_in_fallback_carries_both_iframe_halves(env : &mut TestEnv) {
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19971")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/sign-in", (||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_signin_page(&req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19971/sign-in")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); return }
    var Some(body) = body_opt else unsafe { unreachable }
    var text = body.to_string()
    if(text.find_or_npos(string_view("allow=\"publickey-credentials-get\"")) == std::NPOS) { env.error("fallback iframe must delegate passkeys") }
    if(text.find_or_npos(string_view("/login?next=close")) == std::NPOS) { env.error("fallback iframe must use ?next=close") }
    if(text.find_or_npos(string_view("href=\"https://account.wiqis.com")) != std::NPOS) { env.error("opener must not navigate off-site") }

    stop.shutdown()
}

@test
public func test_every_response_carries_the_account_and_google_csp(env : &mut TestEnv) {
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19972")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/", (||(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_home(&req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19972/")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); return }
    var Ok(resp) = res else unsafe { unreachable }
    var csp = resp.headers.get("Content-Security-Policy")
    if(csp is Option.None) { env.error("no CSP header"); stop.shutdown(); return }
    var Some(value) = csp else unsafe { unreachable }
    if(value.find_or_npos(string_view("accounts.google.com")) == std::NPOS) { env.error("frame-src must name Google for the account popup") }
    if(value.find_or_npos(string_view("account.wiqis.com")) == std::NPOS) { env.error("frame-src must name the account service") }

    stop.shutdown()
}
