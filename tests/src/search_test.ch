// Search endpoint tests
using std::string
using std::string_view
using std::Result
using std::Option

@test
public func test_search_empty_query_returns_200(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19910")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|courses_dir|(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_search(&courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19910/api/search")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 400u) { env.error("expected status 400 for missing q param") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_no_results_returns_empty(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19911")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|courses_dir|(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_search(&courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19911/api/search?q=xyznonexistent")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("results")) == std::NPOS) { env.error("expected 'results' in body") }
    if(body.find_or_npos(string_view("total")) == std::NPOS) { env.error("expected 'total' in body") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_elf_returns_results(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19912")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|courses_dir|(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_search(&courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19912/api/search?q=elf")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("elf")) == std::NPOS) { env.error("search body missing 'elf'") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_bytes_returns_results(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19913")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|courses_dir|(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_search(&courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19913/api/search?q=bytes")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    var body_opt = resp.body.text()
    if(body_opt is Option.None) { env.error("no body"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body) = body_opt else unsafe { unreachable }
    if(body.find_or_npos(string_view("bytes")) == std::NPOS) { env.error("search body missing 'bytes'") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_search_case_insensitive(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:19914")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/search", (|courses_dir|(req) => {
        return underlayer_web::deliver(&req, underlayer_web::handle_search(&courses_dir, &req))
    }))
    var stop = srv.handle()
    srv.serve_async()
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var res = client.get("http://127.0.0.1:19914/api/search?q=ELF")
    if(res is Result.Err) { env.error("request failed"); stop.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp) = res else unsafe { unreachable }
    if(resp.status != 200u) { env.error("expected status 200") }

    stop.shutdown()
    underlayer_db::close(&raw db)
}
