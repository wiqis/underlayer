// Underlayer Ã¢â‚¬â€ Server entrypoint
// Phase 1: Minimal working platform serving static courses.
using std::string
using std::string_view

// ---- Process-wide state ------------------------------------------------
//
// The router stores handlers as `Send + Sync + 'static`, so a handler cannot
// capture the `DbClient` Ã¢â‚¬â€ and a `DbClient` holds the live SQLite handle, which
// is not `Send`. There is one per process, so it lives here and is reached
// through the accessor below. That single `unsafe` read is the whole of the
// process-wide database state; every route stays safe and captures nothing.
//
// It is a POINTER, not a copy: copying a `DbClient` would copy the
// `http::Client`'s mutex and hand out a second view of one connection, which is
// exactly the by-value-capture bug recorded at the /api/exercises/submit route.
//
// The courses directory is process state too, but the web layer is who reads it,
// so it lives there: `underlayer_web::set_courses_dir` / `request_courses_dir`.
@never_destructed
var g_db : *underlayer_db::DbClient

// Fill the value once, before the server starts accepting.
func set_process_state(dbv : *underlayer_db::DbClient, courses : &string) {
    unsafe {
        g_db = dbv
    }
    underlayer_web::set_courses_dir(courses)
}

// The process's database handle.  Valid for the life of the process.
public func request_db() : *underlayer_db::DbClient {
    return unsafe(g_db)
}

// ---- H14: debug-only routes ---------------------------------------------
// A handful of routes exist for the test harness and for the signed-out demo
// flows that tests.exe still drives.  They write persistent rows under the
// shared "demo" identity, so a release build must not expose them: the answer
// is the same 404 an unknown path gets, before any handler or rate limiter
// runs.  Debug and test binaries keep the old behaviour byte-for-byte, which
// is what keeps tests.exe at 138/138.  No state is captured: build provenance
// is read from the environment on each call, exactly as /components already
// does it (I9).
func is_debug_build() : bool {
    var bi = underlayer_core::current_build_info()
    var release_mode = string("release")
    return !bi.build_mode.equals(&release_mode)
}

func debug_only_not_found() : http::Response {
    var body = string("Not found")
    return underlayer_web::send_status_text(404u, &body)
}

// Feature routes that used to write under the shared "demo" identity keep their
// full behaviour in debug (tests.exe drives them). In release they require a
// real session: 401 for anonymous callers, unchanged for signed-in learners.
// This is narrower than a 404 -- a build-mode gate must not silently disable a
// shipped feature for its actual users.
func require_session_in_release(db : *underlayer_db::DbClient, req : &http::Request) : std::Option<http::Response> {
    if(is_debug_build()) { return std::Option.None<http::Response>() }
    if(underlayer_web::has_session(db, req)) { return std::Option.None<http::Response>() }
    var msg = string("Sign in to see your data")
    return std::Option.Some<http::Response>(underlayer_web::send_error(401u, &msg))
}

// ---- Graceful shutdown (H7) ------------------------------------------------
// The upstream HTTP server exposes ShutdownHandle but registers NO OS signal
// handler and does not drain on SIGTERM (verified in lang/libs/http/src/server.ch:
// `serve` only polls `stopping`; `ShutdownHandle.shutdown` is caller-driven).
// The trigger therefore lives here. A C signal handler cannot capture state,
// so one boolean latch is unavoidable here: the stdlib `atomic` module exists
// but `atomic::AtomicU8` collides with `cstd::atomic<T>` in this build, and the
// module-import alias syntax needed to disambiguate it is not supported by
// chemical.mod. A top-level function-call initializer is also unsupported.
// The latch is touched
// only by the handler (write true) and the watcher (read); no route, no FFI
// string and no database access ever goes through it. Those two one-line
// unsafe boundaries are the whole of this process-wide state.
var g_shutdown_requested : bool = false

func on_shutdown_signal(sig : int) {
    unsafe { g_shutdown_requested = true }
}

func shutdown_requested() : bool {
    return unsafe(g_shutdown_requested)
}

func shutdown_watcher(handle : server.ShutdownHandle) {
    while(!shutdown_requested()) {
        std::concurrent.sleep_ms(100u)
    }
    var msg = std::string("[underlayer] shutdown signal received; stopping accept loop (active requests drain <=30s via body timeout)")
    underlayer_core::log_line(&msg)
    handle.shutdown()
}

public func main() : int {
    // ---- Config & DB ----
    var cfg = underlayer_core::load_config()
    var port = cfg.port
    var db_url = cfg.db_url.copy()
    var db_token = cfg.db_token.copy()

    // H5: a release build with no provenance must not serve traffic.
    var bi = underlayer_core::current_build_info()
    if(!underlayer_core::validate_build_info(&bi)) {
        var fatal_bi = underlayer_core::build_info_failure_message(&bi)
        underlayer_core::log_line(&fatal_bi)
        return 1
    }
    var provenance = underlayer_core::build_info_startup_line(&bi)
    underlayer_core::log_line(&provenance)

    var start_msg = std::string("[underlayer] Starting Underlayer on port ")
    start_msg.append_string(&underlayer_core::u32_to_string(port))
    underlayer_core::log_line(&start_msg)

    var db = underlayer_db::make_client(db_url.copy(), db_token.copy())
    var courses_dir_value = cfg.courses_dir.copy()
    set_process_state(&raw db, &courses_dir_value)

    // ---- REFUSE AN UNUSABLE DATABASE, BEFORE SERVING ANYTHING ---------
    //
    // Measured on 2026-10-02 with the URL the Dockerfile documents as the
    // production setting:
    //
    //     DATABASE_URL="libsql://example.invalid" ./underlayer.exe
    //       -> /api/health  200
    //       -> POST /api/auth/register  {"error":"could not create the account"}
    //
    // The remote (Turso/libSQL) backend is not implemented in this build, so
    // every query and every write fails -- while the server reports itself
    // healthy and accepts traffic.  A half-working configuration is worse than a
    // refused one: it fails at 3am, discovered by a learner whose registration
    // vanished, rather than at deploy time by the person deploying.
    //
    // So this exits BEFORE the schema init, the seeding and the accept loop.
    // `is_unusable_config` also catches a local SQLite path that could not be
    // opened, which has the same shape: everything answers, nothing is stored.
    var sqlite_ok = false
    if(db.is_sqlite && db.sqlite_handle != null) { sqlite_ok = true }
    if(underlayer_db::is_unusable_config(&db_url, sqlite_ok)) {
        var fatal = underlayer_db::unusable_config_message(&db_url)
        underlayer_core::log_line(&fatal)
        return 1
    }
    var ok_msg = std::string("[underlayer] Database OK: ")
    ok_msg.append_string(&db_url)
    underlayer_core::log_line(&ok_msg)
    var courses_dir_pre = cfg.courses_dir.copy()

    // ---- Init schema (skip for remote DB) ----
    if(!underlayer_db::is_remote_url(&db_url)) {
        underlayer_repository::init_schema(&raw db)
        // G1/G2/G4: additive tables with no ALTER of an existing table. Safe to
        // run on every boot and on a throwaway database.
        underlayer_web::init_g_tables(&raw db)

        // 4.1.27: seed exercises from course manifests at startup (idempotent).
        // Multi-course: loop every course directory found on disk.
        var all_courses = underlayer_repository::list_courses(&courses_dir_pre)
        var seeded_total : i64 = 0
        var prereq_total : i64 = 0
        var ci : size_t = 0
        while(ci < all_courses.size()) {
            var cptr = all_courses.at_ref(ci)
            var cid = cptr.id.copy()
            var seeded = underlayer_repository::seed_exercises_from_manifest(&raw db, &courses_dir_pre, &cid)
            seeded_total = seeded_total + seeded
            // COURSE PREREQUISITES, from the same manifests and in the same loop.
            //
            // 32 of the 34 manifests declare `dependencies`, and before this
            // nothing ever wrote them anywhere: `course_prerequisites` held zero
            // rows, so GET /api/courses/:id/can-enroll answered
            // `{"can_enroll": true}` for EVERY course on the platform. The
            // prerequisite checks all existed and all read an empty table -- a
            // shipped feature that always says yes, which is worse than an absent
            // one, because the checklist claims it exists.
            //
            // Idempotent, and it also PRUNES: a dependency removed from a
            // manifest stops being enforced, because the table is derived state
            // and derived state has to be allowed to shrink.
            var man_course = underlayer_repository::load_course(&courses_dir_pre, &cid)
            if(man_course.id.size() > 0) {
                var np = underlayer_repository::seed_prerequisites_from_manifest(&raw db, &man_course)
                prereq_total = prereq_total + np
            }
            ci = ci + 1
        }
        if(seeded_total > 0) {
            var seed_msg = std::string("[underlayer] Seeded ")
            seed_msg.append_string(&underlayer_core::int_to_string(seeded_total))
            seed_msg.append_view(" exercises from manifests")
            underlayer_core::log_line(&seed_msg)
        }
    }

    // ---- HTTP Server ----
    var cfg_server = server.ServerConfig()
    var addr = std::string(":")
    var port_str = underlayer_core::u32_to_string(port)
    addr.append_view(port_str.to_view())
    cfg_server.addr = addr
    // H7: explicit timeout and concurrency contract. 12 workers matches the
    // documented pool size; per-request work is bounded by a 5 s header read
    // and a 30 s body read, which also bounds shutdown draining to <=30 s.
    cfg_server.worker_count = 12u
    cfg_server.header_timeout_secs = 5
    cfg_server.body_timeout_secs = 30
    cfg_server.max_inflight = 256u
    var timeout_msg = std::string("[underlayer] server config: worker_count=12 header_timeout_secs=5 body_timeout_secs=30 max_inflight=256")
    underlayer_core::log_line(&timeout_msg)
    var srv = server.Server(cfg_server)
    var shutdown_handle = srv.handle()
    var watcher = std::thread.spawn_void(shutdown_watcher, shutdown_handle)
    var sigterm_rc = unsafe(signal(SIGTERM, on_shutdown_signal))
    var sigint_rc = unsafe(signal(SIGINT, on_shutdown_signal))
    comptime if(def.windows) {
        var sigbreak_rc = unsafe(signal(SIGBREAK, on_shutdown_signal))
    }

    // Shared courses_dir for route handlers
    var courses_dir = cfg.courses_dir.copy()

    // ---- Routes ----

    // ---- Learner CRUD ----
    srv.router.add("POST", "/api/learners", ||(req) => {
        var db = request_db()
        // RATE LIMITED.
        // 8 per 5 min -- the AUTH ceiling, not the learning one, because this inserts into `learners`, which is the ACCOUNTS table.
        // Measured before this: it answered 200 to an unauthenticated caller, forever, and every call attempted an INSERT with a hardcoded email and no password.
        // It reads no request body at all and exists for tests/src/additional_api_test.ch
        // See web/src/rate_limit.ch. The limiter function existed but had no
        // CALL SITE until H4's live gate caught it: the route answered 200
        // forever and wrote no bucket row. A local copy gives the by-value
        // closure a real *DbClient (the &raw db capture shape compiles but
        // silently never runs -- checklist 2.2.63).
        var dbp = db
        var gate = underlayer_web::rate_limit_create_learner(dbp, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        // H14: test-only route. It inserts into `learners` with a hardcoded
        // identity and no credentials, so release answers like an unknown path.
        // Debug keeps it for tests/src/additional_api_test.ch (138/138). The
        // limiter above still runs in both modes: security_check's existing
        // bucket assertion must keep proving the gate fires, and a rate-limit
        // bucket is infrastructure, not a learner row.
        if(!is_debug_build()) {
            return underlayer_web::deliver_with_learner(request_db(), &req, debug_only_not_found())
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_create_learner(db, &req))
    })
    srv.router.add("GET", "/api/learners/:learnerId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var learner_id = segments.at_ref(2)
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_learner(db, learner_id, &req))
        } else {
            var body = std::string("{\"error\": \"missing learner id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Health check ----
    // H5: additive provenance fields. `status` and `version` keep their exact
    // bytes, because clients and the served-behaviour checkers parse them.
    srv.router.add("GET", "/api/health", ||(req) => {
        var body = underlayer_core::health_json_with_build_info()
        // H17: additive kill-switch state. The two fields are the wire-proof
        // that a flag flip took effect without a rebuild; status/version and
        // the H5 provenance fields keep their exact bytes.
        var body_view = body.to_view()
        var prefix = body_view.subview(0, body.size() - 1)
        var flagged = string()
        flagged.append_view(&prefix)
        flagged.append_view(",\"paid_gating_enabled\":\"")
        var paid = underlayer_core::flag_state(underlayer_core::paid_gating_enabled())
        var paid_view = paid.to_view()
        flagged.append_view(&paid_view)
        flagged.append_view("\",\"learner_surface_v2\":\"")
        var v2 = underlayer_core::flag_state(underlayer_core::learner_surface_v2())
        var v2_view = v2.to_view()
        flagged.append_view(&v2_view)
        flagged.append_view("\"}")
        body = flagged
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_str(&body))
    })

    // Review page (HTML UI)
    srv.router.add("GET", "/review", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_review_page(db, &courses_dir, &req))
    })
    // Progress page (HTML UI)
    srv.router.add("GET", "/progress", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_progress_page(db, &courses_dir, &req))
    })
    // Dashboard page (7.2.4, 7.2.5, 1.5.20)
    srv.router.add("GET", "/dashboard", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_dashboard(db, &courses_dir, &req))
    })
    // Knowledge Health page. Server-rendered from the learner's own rows, so it
    // works with JS off; gated because unsigned it would be four zeroes.
    srv.router.add("GET", "/health", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_knowledge_health_page(db, &courses_dir, &req))
    })
    // F3: additive `paid` flag on the course list. Registered BEFORE the
    // original handler; the original stays untouched and is still used for
    // every other surface.
    srv.router.add("GET", "/api/courses", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_list_courses_with_paid(&courses_dir, &req))
    })
    // F4: the Android entitlement read. Forwarded to the account service with
    // the caller's own token; nothing is cached or stored on the device.
    srv.router.add("GET", "/api/entitlements/me", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_entitlements_me(&req))
    })
    // Course listing
    srv.router.add("GET", "/api/courses", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_list_courses(&courses_dir, &req))
    })
    // Filter Courses (7.1.7)
    srv.router.add("GET", "/api/courses/all", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_filter_courses(&courses_dir, &req))
    })
    // Course detail
    srv.router.add("GET", "/api/courses/:courseId", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2)
            // Course METADATA stays public even for a paid course: the crawler,
            // the SEO checker and the purchase page need it. Only lesson CONTENT
            // is gated (see the literal binread lesson routes).
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_course(&courses_dir, course_id, &req))
        } else {
            var body = std::string("{\"error\": \"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // F3: the paid course's lesson endpoints. Literal course segment so only
    // binread is intercepted; every free course keeps the routes below.
    srv.router.add("GET", "/api/courses/binread/lessons/:conceptId", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 5) {
            var concept_id = segments.at_ref(4)
            var concept_s = std::string(concept_id)
            var cid = std::string("binread")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_paid_lesson(request_db(), &courses_dir, &cid, &concept_s, &req))
        }
        var err = std::string("{\"error\":\"missing concept id\"}")
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &err))
    })
    // S-1: structured unit index for the Android stepper, derived from the
    // exact HTML render_concept produces.  Registered BEFORE the lesson route
    // so the literal "units" tail is never swallowed by :conceptId.
    srv.router.add("GET", "/api/courses/:courseId/lessons/:conceptId/units", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 6) {
            var course_id = segments.at_ref(2)
            var concept_id = segments.at_ref(4)
            var tail = segments.at_ref(5)
            var units_tail = std::string_view("units")
            if(tail.equals(&units_tail)) {
                return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_lesson_units(&courses_dir, course_id, concept_id, &req))
            }
        }
        var body = std::string("{\"error\":\"missing course or concept id\"}")
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
    })
    // Native lesson JSON for the Android client.  Same frozen contract as the
    // static .native.json companion.  Registered BEFORE the generic lesson
    // route so the literal "native" tail is not swallowed by :conceptId.
    // Segment indices are absolute positions in the /api-prefixed path:
    // course = 2, concept = 4, tail = 5 (do not use the page-route indices).
    srv.router.add("GET", "/api/courses/:courseId/lessons/:conceptId/native", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 6) {
            var course_id = segments.at_ref(2)
            var concept_id = segments.at_ref(4)
            var tail = segments.at_ref(5)
            var native_tail = std::string_view("native")
            if(tail.equals(&native_tail)) {
                return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_lesson_native(&courses_dir, course_id, concept_id, &req))
            }
        }
        var body = std::string("{\"error\":\"missing course or concept id\"}")
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
    })
    // Lesson viewer via API
    srv.router.add("GET", "/api/courses/:courseId/lessons/:conceptId", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        // Segment indices are absolute positions in the path, and this path
        // starts with /api -- so the course is segments[2] and the concept
        // segments[4].  It used to read 1 and 3, which are the literal words
        // "courses" and "lessons", so handle_lesson was always asked for a
        // course named "courses" and answered 404 for every lesson in the
        // product.  The page route /courses/:courseId/lessons/:conceptId below
        // has no /api prefix and is correctly 1 and 3 -- do not "fix" that one
        // to match this.
        if(segments.size() >= 5) {
            var course_id = segments.at_ref(2)
            var concept_id = segments.at_ref(4)
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_lesson(&courses_dir, course_id, concept_id, &req))
        } else {
            var body = std::string("{\"error\": \"missing course or concept id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Review API ----
    srv.router.add("GET", "/api/review/start", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_review_start(db, &courses_dir, &req))
    })
    // G4: the browser sends its check-in in a POST body; the GET route above
    // stays for API clients that only use query params.
    srv.router.add("POST", "/api/review/start", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_review_start(db, &courses_dir, &req))
    })
    srv.router.add("POST", "/api/review/energy", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_review_energy(db, &req))
    })
    srv.router.add("POST", "/api/review/submit", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_review_submit(db, &mut req))
    })
    srv.router.add("POST", "/api/review/end", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_review_end(db, &req))
    })
    // ---- Due Items ----
    srv.router.add("GET", "/api/review/due", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_review_due(db, &courses_dir, &req))
    })
    // ---- Session Recommendations (1.2.25) ----
    srv.router.add("GET", "/api/review/recommendations", ||(req) => {
        var db = request_db()
        // I9: due counts describe ONE learner's queue. With no session the
        // handler used to answer for the shared "demo" row, so a signed-out
        // reader was shown numbers that looked like theirs. No session, no data.
        if(!underlayer_web::has_session(db, &req)) {
            var msg = string("Sign in to see your data")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &msg))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_recommendations(db, &req))
    })
    // ---- Time-of-Day Recommendation (1.2.27) ----
    srv.router.add("GET", "/api/review/time-recommendation", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_time_recommendation(db, &req))
    })
    // ---- Search (7.1.6) ----
    srv.router.add("GET", "/api/search", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_search(&courses_dir, &req))
    })
    // Concept search: titles, descriptions, module names and course titles
    // across all courses. Additive â€” /api/search's response shape is a
    // shipped contract and is left alone.
    srv.router.add("GET", "/api/search/concepts", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_search_concepts(&courses_dir, &req))
    })
    // NOTE: "GET /api/courses/all" (Filter Courses, 7.1.7) is already
    // registered near the top of this file, directly after GET /api/courses.
    // It used to be registered a SECOND time here, byte-identical handler and
    // all, which left the router holding two entries for one path -- dead
    // configuration that reads like a second, different endpoint and that
    // tools/route_check.py flagged.  One registration, one route.

    // ---- Recent History (7.1.9) ----
    srv.router.add("GET", "/api/recent", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_recent_history(db, &req))
    })
    // ---- Progress API ----
    srv.router.add("GET", "/api/progress", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        // I9: personal learning data. 401 rather than the demo learner's row.
        if(!underlayer_web::has_session(db, &req)) {
            var msg = string("Sign in to see your data")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &msg))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_progress(db, &courses_dir, &req))
    })
    // ---- What am I doing: courses in progress, coverage, and the exercises
    // this learner got wrong (4.4.3).  One payload because /dashboard draws
    // all three at once and three round trips would make it flash.
    // Deliberately NOT /api/progress/overview: that path is already claimed by
    // the /api/progress/:courseId route above and would be swallowed by it.
    srv.router.add("GET", "/api/me/overview", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        // I9: the route is literally named "me". An anonymous caller has no
        // overview; answering with an empty/demo one invites a false reading.
        if(!underlayer_web::has_session(db, &req)) {
            var msg = string("Sign in to see your data")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &msg))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_my_overview(db, &courses_dir, &req))
    })
    // ---- Which quiz did I fail.  The same list without the course summary. ----
    srv.router.add("GET", "/api/exercises/failures", ||(req) => {
        var db = request_db()
        // I9: a list of exercises THIS learner got wrong is personal data.
        if(!underlayer_web::has_session(db, &req)) {
            var msg = string("Sign in to see your data")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &msg))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_exercise_failures(db, &req))
    })
    // ---- Progress Export (6.1.7) ----
    srv.router.add("GET", "/api/progress/export", ||(req) => {
        var db = request_db()
        // I9: a data export is the purest form of personal data. Never export
        // the shared demo row to an unauthenticated caller.
        if(!underlayer_web::has_session(db, &req)) {
            var msg = string("Sign in to see your data")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &msg))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_progress_export(db, &req))
    })
    // ---- Session Analytics (6.2.1) ----
    srv.router.add("GET", "/api/analytics/sessions", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_analytics(db, &req))
    })
    // ---- Concept Analytics (6.2.2) ----
    srv.router.add("GET", "/api/analytics/concept/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.at_ref(3)
            var course_id = string("elf")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_concept_analytics(db, concept_id, &req))
        } else {
            var body = std::string("{\"error\": \"missing concept id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Course Analytics (6.2.3) ----
    srv.router.add("GET", "/api/analytics/course/:courseId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.at_ref(3)
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_course_analytics(db, course_id, &req))
        } else {
            var body = std::string("{\"error\": \"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Difficulty Analytics (6.2.8) ----
    srv.router.add("GET", "/api/analytics/difficulty", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_difficulty_analytics(db, &req))
    })
    // ---- Error Analytics (6.2.9) ----
    srv.router.add("GET", "/api/analytics/errors", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_error_analytics(db, &req))
    })
    // ---- Engagement Analytics (6.2.13) ----
    srv.router.add("GET", "/api/analytics/engagement", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_engagement_analytics(db, &req))
    })
    // ---- Velocity Analytics (6.2.14) ----
    srv.router.add("GET", "/api/analytics/velocity", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_velocity_analytics(db, &req))
    })
    // ---- Learning Analytics (P2 6.2.4-6.2.7, 6.2.10-6.2.12, 6.2.15) ----
    srv.router.add("GET", "/api/analytics/temporal", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_temporal_analytics(db, &req))
    })
    srv.router.add("GET", "/api/analytics/retention", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_retention_analytics(db, &req))
    })
    srv.router.add("GET", "/api/analytics/dropoff", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_dropoff_analytics(db, &req))
    })
    srv.router.add("GET", "/api/analytics/funnel", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_funnel_analytics(db, &req))
    })
    srv.router.add("GET", "/api/analytics/comparative", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_comparative_analytics(db, &req))
    })
    srv.router.add("GET", "/api/analytics/platform", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_platform_analytics(db, &req))
    })
    srv.router.add("GET", "/api/analytics/cohorts", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_cohort_analytics(db, &req))
    })
    srv.router.add("GET", "/api/analytics/devices", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_device_analytics(db, &req))
    })
    // ---- Mobile progress sync (S-2).  Registered BEFORE
    // /api/progress/:courseId: otherwise "sync" is read as a course id. ----
    srv.router.add("GET", "/api/progress/sync", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_progress_sync_pull(db, &req))
    })
    srv.router.add("POST", "/api/progress/sync", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_progress_sync_push(db, &mut req))
    })
    // ---- G13: safe guest -> account takeover. Both literals precede the
    // /api/progress/:courseId route below so "takeover" is never a course id. ----
    srv.router.add("POST", "/api/progress/takeover/token", ||(req) => {
        var db = request_db()
        // H14/CI: this inserts a one-shot token row. In release only a signed-in
        // learner may create it; debug keeps the old behaviour for tests.
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(db, &req, refusal)
        }
        return underlayer_web::deliver_with_learner(db, &req, underlayer_web::handle_takeover_token(db, &req))
    })
    srv.router.add("POST", "/api/progress/takeover", ||(req) => {
        var db = request_db()
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(db, &req, refusal)
        }
        return underlayer_web::deliver_with_learner(db, &req, underlayer_web::handle_progress_takeover(db, &mut req))
    })
    // ---- Course Progress API ----
    srv.router.add("GET", "/api/progress/:courseId", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        // I9: per-course progress is the visitor's own learning state. Gate
        // before the demo fallback in the handler; /api/progress/elf included.
        if(!underlayer_web::has_session(db, &req)) {
            var msg = string("Sign in to see your data")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &msg))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_course_progress(db, &courses_dir, &req))
    })
    // ---- Learning Goals (6.1.5) ----
    // GET was missing: the feature could write a goal and never read one back.
    srv.router.add("GET", "/api/goals", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_goals(db, &req))
    })
    srv.router.add("POST", "/api/goals", ||(req) => {
        // H14: an anonymous goal writes learning_goals under the shared demo id.
        var db = request_db()
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_set_goal(db, &mut req))
    })
    srv.router.add("DELETE", "/api/goals", ||(req) => {
        // H14: the same demo bucket could also be DELETED by an anonymous caller.
        var db = request_db()
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_delete_goal(db, &req))
    })
    // ---- Weakness Dashboard (1.4.21) ----
    srv.router.add("GET", "/api/weaknesses", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_weakness_dashboard(db, &req))
    })
    // ---- Weakness Export (1.4.23) ----
    srv.router.add("GET", "/api/weaknesses/export", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_weakness_export(db, &req))
    })
    // ---- Weakness Compare (1.4.22) ----
    srv.router.add("GET", "/api/weaknesses/compare", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_weakness_compare(db, &req))
    })
    // ---- Weakness Alerts (1.4.24) ----
    srv.router.add("GET", "/api/weaknesses/alerts", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_weakness_alerts(db, &req))
    })
    // ---- Navigation API (7.1.2, 7.1.3, 7.1.5) ----
    // THE SAME TREE, WITHOUT A CONCEPT, and this route exists because
    // /api/navigation required a concept id that a caller asking "what order are
    // these lessons in?" does not have.
    //
    // Measured while building web/src/next_step.ch: the panel needs every concept
    // in course order, and it has no current concept -- it is on the dashboard,
    // not in a lesson. The only way to get the tree was to invent a placeholder
    // concept id, and an invented id returns 200 with the full tree, which means
    // the parameter was never load-bearing for the tree. It only adds prev/next
    // and breadcrumbs.
    //
    // So the tree is now reachable honestly, and a caller that has a concept
    // still uses the two-parameter form. Both routes share ONE handler, so there
    // is no second copy of the tree to drift.
    srv.router.add("GET", "/api/navigation/:courseId", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2)
            // An empty concept id makes the handler omit the breadcrumbs and the
            // prev/next block, which is exactly the difference wanted here.
            var no_concept = std::string_view("")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_navigation(&courses_dir, course_id, &no_concept, &req))
        } else {
            var body = std::string("{\"error\": \"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/api/navigation/:courseId/:conceptId", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.at_ref(2)
            var concept_id = segments.at_ref(3)
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_navigation(&courses_dir, course_id, concept_id, &req))
        } else {
            var body = std::string("{\"error\": \"missing course or concept id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Nav Status (P2 7.1.13 progress indicator, P2 7.1.15 due indicator) ----
    // Takes ?course_id= because the bar it feeds is drawn by the per-course
    // landing nav; it used to report elf's numbers on every course page.
    srv.router.add("GET", "/api/nav-status", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        // I9: concepts started/mastered and the due badge belong to a learner.
        // An anonymous page simply has no bar to paint; it must not paint the
        // shared demo learner's bar and call it the visitor's progress.
        if(!underlayer_web::has_session(db, &req)) {
            var msg = string("Sign in to see your data")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &msg))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_nav_status(db, &courses_dir, &req))
    })
    // ---- Nav Search / Quick Jump (P2 7.1.10 command palette) ----
    srv.router.add("GET", "/api/nav-search", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_nav_search(&req))
    })

    // ---- FSRS Settings (1.1.24-1.1.28) ----
    srv.router.add("POST", "/api/fsrs/optimize", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_fsrs_optimize(db, &req))
    })
    srv.router.add("POST", "/api/fsrs/reset", ||(req) => {
        var db = request_db()
        // H14/CI: reset writes a per-learner fsrs_params row; release requires
        // a real session so an anonymous caller cannot create persistent state.
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(db, &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_fsrs_reset(db, &req))
    })
    srv.router.add("GET", "/api/fsrs/export", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_fsrs_export(db, &req))
    })
    srv.router.add("POST", "/api/fsrs/import", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_fsrs_import(db, &mut req))
    })
    srv.router.add("POST", "/api/fsrs/params", ||(req) => {
        var db = request_db()
        // H14/CI: writes a per-learner fsrs_params row. Release requires a
        // session; debug keeps the old behaviour for the unit suite.
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(db, &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_fsrs_params(db, &req))
    })
    // ---- Session History (1.2.21, 1.2.22) ----
    srv.router.add("GET", "/api/sessions", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_history(db, &req))
    })
    // ---- Session Detail (1.2.22) ----
    srv.router.add("GET", "/api/sessions/:sessionId", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_detail(db, &req))
    })
    srv.router.add("GET", "/api/session/detail", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_detail(db, &req))
    })
    // ---- Session Management (1.2.9-1.2.13) ----
    srv.router.add("POST", "/api/session/pause", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_pause(db, &req))
    })
    srv.router.add("POST", "/api/session/resume", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_resume(db, &req))
    })
    srv.router.add("POST", "/api/session/abort", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_abort(db, &req))
    })
    srv.router.add("POST", "/api/session/undo", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_undo(db, &req))
    })
    srv.router.add("POST", "/api/session/skip", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_session_skip(db, &req))
    })
    // ---- Bulk Exercise Import API ----
    srv.router.add("POST", "/api/exercises/import", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::refuse_exercise_import(db, &req))
    })
    srv.router.add("POST", "/api/exercises/seed", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::refuse_exercise_seed(db, &req))
    })
    srv.router.add("GET", "/api/exercises/stats", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_exercise_stats(db, &req))
    })
    // I2: THE HINT ROUTE MUST BE REGISTERED BEFORE /api/exercises/:conceptId.
    // The router is first-match-wins in registration order. With the literal
    // route below the parameterised one, GET /api/exercises/hint was captured
    // as conceptId="hint" and answered 200 {"concept_id":"hint","exercises":[],
    // "total":0}; the progressive hints (G4's retry ladder) were unreachable.
    // tools/literal_route_shadow_check.py fails a planted regression of this.
    srv.router.add("GET", "/api/exercises/hint", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_exercise_hint(db, &req))
    })
    // ---- Exercise API (4.1.1-4.1.5, 4.2.1-4.2.5) ----
    srv.router.add("GET", "/api/exercises/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var concept_id = segments.at_ref(2)
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_exercises(db, concept_id, &req))
        } else {
            var body = std::string("{\"error\": \"missing concept id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // THE RATE-LIMIT GATE ON THIS ROUTE, and the reason this closure captures
    // `db` BY REFERENCE while every other gated route captures it by value.
    //
    // Measured: with the `*DbClient` gate and a by-value capture, this compiled,
    // the gate string was in the binary, and the gate NEVER RAN. 125 consecutive
    // submissions answered 200 and no `exercise_submit` bucket was ever written.
    // The same gate on /api/feedback, /api/learners and the four auth routes --
    // all by-value captures -- works. The difference is the capture, not the gate.
    //
    // Two conclusions, and the second is the one that matters:
    //   * `rate_limit_ok` now has a `&DbClient` entry point, because a
    //     by-reference closure can pass `db` and cannot pass `&raw db` usefully.
    //   * A limiter that silently never fires is WORSE THAN NO LIMITER, because
    //     it reads as coverage. tools/security_check.py CHECK 15 now fires every
    //     gate and asserts each one refuses, so "the gate is in the source" is
    //     no longer something anyone has to take on faith.
    srv.router.add("POST", "/api/exercises/submit", ||(req) => {
        var db = request_db()
        // RATE LIMITED.
        // 120 per 5 min.
        // Measured before this: ten submissions in ten consecutive requests, all
        // accepted.
        // Each inserts into exercise_attempts and re-grades, so it is both a write
        // amplifier and a way to manufacture a flattering history -- a learner could
        // inflate their own accuracy, or manufacture weaknesses to dodge a review
        // they did not do.
        // 120 is ten times what a reviewer doing a course in one sitting produces
        // A LOCAL COPY, not `&raw db`.  In a closure that captures `db` BY
        // REFERENCE, `&raw db` compiles, is present in the binary, and never
        // runs -- measured: 125 submissions, 125 x 200, no bucket row.  Copying
        // first gives a real *DbClient, which is the only thing
        // rate_limit_ok_with can actually use.
        var dbp = db
        var gate = underlayer_web::rate_limit_exercise_submit(dbp, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_exercise_submit(db, &mut req))
    })
    // Course index â€” /courses. Registered BEFORE /courses/:courseId so the
    // exact path wins over the parameterised one. This is the page every
    // lesson's "All courses" back-link points at, 42 times across 32 files,
    // and it did not exist until now; tools/link_check.py is what stops that
    // from being true again.
    // /courses Ã¢â‚¬â€ the collection index.
    srv.router.add("GET", "/courses", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_courses_page(&courses_dir, &req))
    })
    // Learning path â€” the three routes through the collection. Distinct from
    // /courses/:courseId/path, which is the per-course dependency graph.
    // /learning-path Ã¢â‚¬â€ the three routes in full.
    srv.router.add("GET", "/learning-path", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_learning_path_index(&courses_dir, &req))
    })
    // Search â€” concept search, server-rendered from ?q=
    // /search Ã¢â‚¬â€ server-rendered from ?q=.
    srv.router.add("GET", "/search", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(db, &req,
            underlayer_web::handle_search_page_db(db, &underlayer_web::request_courses_dir(), &req))
    })
    // Course landing page
    srv.router.add("GET", "/courses/:courseId", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            var course_id = segments.at_ref(1)
            // The landing page is the public store front for a paid course;
            // lesson content is gated by the literal route below.
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_course_landing(db, &courses_dir, course_id, &req))
        } else {
            var home = std::string("/")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::redirect_to(&home))
        }
    })
    // F3: the paid course's browser lesson. Literal course segment; free
    // courses continue through the generic route below.
    srv.router.add("GET", "/courses/binread/lessons/:conceptId", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.at_ref(3)
            var concept_s = std::string(concept_id)
            var cid = std::string("binread")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_paid_lesson(request_db(), &courses_dir, &cid, &concept_s, &req))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(400u, &std::string("missing concept id")))
    })
    // Lesson viewer via URL path
    srv.router.add("GET", "/courses/:courseId/lessons/:conceptId", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.at_ref(1)
            var concept_id = segments.at_ref(3)
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_lesson(&courses_dir, course_id, concept_id, &req))
        } else {
            var body = std::string("Not found")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_status_text(404u, &body))
        }
    })
    // I5: the only nested /courses/* assets a learner may download. Registered
    // BEFORE the catch-all below; the handler validates the raw segments and
    // rebuilds the filename from an allow-listed course id, so a traversal or
    // an absolute path can never reach path::Path.
    srv.router.add("GET", "/courses/:course/assets/samples/:file", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_specimen_download(&courses_dir, &req))
    })
    // Static file serving for course output (HTML, CSS, JS, images)
    srv.router.add("GET", "/courses/*", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        var path = req.path.to_view()
        // Only serve files, not directory paths (must have an extension)
        var has_ext = false
        var i : size_t = 0
        while(i < path.size()) {
            if(path.at(i) == '.') { has_ext = true }
            i = i + 1
        }
        if(has_ext) {
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_static_file(&courses_dir, &path))
        } else {
            // Try course landing page
            var segments = underlayer_core::path_segments(&path)
            if(segments.size() >= 2) {
                var course_id = segments.at_ref(1)
                return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_course_landing(db, &courses_dir, course_id, &req))
            } else {
                var home = std::string("/")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::redirect_to(&home))
            }
        }
    })
    // ---- I1: organic discovery surface ---------------------------------
    // Explicit routes BEFORE the web::App catch-all. They go through
    // deliver_with_learner, so H3's uniform security headers, the access line,
    // ETag/304 and gzip apply to them exactly as to every handler route.
    srv.router.add("GET", "/robots.txt", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_robots_txt(&req))
    })
    srv.router.add("GET", "/sitemap.xml", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_sitemap_xml(&courses_dir, &req))
    })
    srv.router.add("GET", "/favicon.ico", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_favicon_ico(&req))
    })
    // Home page Ã¢â‚¬â€ a per-request response (see the note on handle_home).
    srv.router.add("GET", "/", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_home(&req))
    })

    // ---- Account management routes (Section 16) ----
    // Auth pages
    srv.router.add("GET", "/login", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_login_page(&req))
    })
    srv.router.add("GET", "/register", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_register_page(&req))
    })
    // The no-JavaScript fallbacks.  Their hrefs are LOCAL â€” a sign-in control
    // that navigated to the account host would lose the reader's page and is
    // the exact anti-pattern the embedded-sign-in contract forbids.
    srv.router.add("GET", "/sign-in", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_signin_page(&req))
    })
    srv.router.add("GET", "/sign-up", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_signup_page(&req))
    })
    srv.router.add("GET", "/sign-out", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_signout_page(&req))
    })
    srv.router.add("GET", "/forgot-password", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_forgot_password_page(&req))
    })
    srv.router.add("GET", "/reset-password", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_reset_password_page(&req))
    })
    // Settings page
    srv.router.add("GET", "/settings", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_settings_page(&req))
    })
    // I11: public support channel, server-rendered with no JS dependency.
    srv.router.add("GET", "/support", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_support_page(&req))
    })
    srv.router.add("GET", "/components", ||(req) => {
        // I9: the component gallery is a developer showcase (~124 KB), not a
        // learner page. It is reachable only in a local debug/test binary, via
        // the existing UL_BUILD_MODE env flag; a release-like binary answers
        // exactly like any other unknown path. No extra global state, no
        // capture in the route closure, and no weakening of any other gate.
        var bi = underlayer_core::current_build_info()
        var release_mode = string("release")
        if(bi.build_mode.equals(&release_mode)) {
            var body = std::string("Not found")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_status_text(404u, &body))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_components_demo_page(&req))
    })
    srv.router.add("GET", "/u/:username", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(db, &req,
            underlayer_web::handle_public_proof_page(db, &req))
    })
    // Rate-limit bucket names.  Declared here rather than inline as literals
    // at the four call sites so the set of guarded endpoints is readable in
    // one place, and so the four are named identically by construction.

    // Auth API (from handlers_auth.ch)
    srv.router.add("POST", "/api/auth/register", ||(req) => {
        var db = request_db()
        // RATE LIMITED: 8 attempts per 5 minutes per IP.  bcrypt cost 12 costs
        // this server ~0.44s of CPU per login attempt, so an unthrottled login
        // endpoint is a denial-of-service from a single HTTP client.  Measured
        // before the limiter: twelve wrong passwords in a row, twelve 401s, no
        // delay and no counter.  See web/src/rate_limit.ch.
        var gate = underlayer_web::rate_limit_register(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_register(db, &mut req))
    })
    srv.router.add("POST", "/api/auth/login", ||(req) => {
        var db = request_db()
        // RATE LIMITED: 8 attempts per 5 minutes per IP.  bcrypt cost 12 costs
        // this server ~0.44s of CPU per login attempt, so an unthrottled login
        // endpoint is a denial-of-service from a single HTTP client.  Measured
        // before the limiter: twelve wrong passwords in a row, twelve 401s, no
        // delay and no counter.  See web/src/rate_limit.ch.
        var gate = underlayer_web::rate_limit_login(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_login(db, &mut req))
    })
    srv.router.add("POST", "/api/auth/logout", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_logout(db, &req))
    })
    srv.router.add("GET", "/api/auth/me", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_me(db, &req))
    })
    // POST /api/auth/from-account â€” exchange a SHARED account credential for a
    // local session.  Acceptance is checked against account.wiqis.com; only a
    // stable user id crosses back, and all learning data stays in this DB.
    // RATE LIMITED at the auth ceiling, like login and register.
    srv.router.add("POST", "/api/auth/from-account", ||(req) => {
        var db = request_db()
        var gate = underlayer_web::rate_limit_from_account(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_from_account(db, &req))
    })
    srv.router.add("POST", "/api/auth/forgot-password", ||(req) => {
        var db = request_db()
        // RATE LIMITED: 8 attempts per 5 minutes per IP.  bcrypt cost 12 costs
        // this server ~0.44s of CPU per login attempt, so an unthrottled login
        // endpoint is a denial-of-service from a single HTTP client.  Measured
        // before the limiter: twelve wrong passwords in a row, twelve 401s, no
        // delay and no counter.  See web/src/rate_limit.ch.
        var gate = underlayer_web::rate_limit_forgot(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_forgot_password(db, &mut req))
    })
    srv.router.add("POST", "/api/auth/reset-password", ||(req) => {
        var db = request_db()
        // RATE LIMITED: 8 attempts per 5 minutes per IP.  bcrypt cost 12 costs
        // this server ~0.44s of CPU per login attempt, so an unthrottled login
        // endpoint is a denial-of-service from a single HTTP client.  Measured
        // before the limiter: twelve wrong passwords in a row, twelve 401s, no
        // delay and no counter.  See web/src/rate_limit.ch.
        var gate = underlayer_web::rate_limit_reset(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_reset_password(db, &mut req))
    })
    srv.router.add("POST", "/api/auth/verify-email", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_verify_email(db, &mut req))
    })
    srv.router.add("GET", "/api/user/login-history", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_login_history(db, &req))
    })
    // Profile API (from handlers_profiles.ch)
    srv.router.add("GET", "/api/user/profile", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_profile(db, &req))
    })
    srv.router.add("PUT", "/api/user/profile", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_update_profile(db, &req))
    })
    // Settings API (from handlers_settings.ch)
    srv.router.add("GET", "/api/user/settings", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_settings(db, &req))
    })
    srv.router.add("PUT", "/api/user/settings", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_update_settings(db, &req))
    })
    srv.router.add("GET", "/api/user/learning-preferences", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_learning_preferences(db, &req))
    })
    srv.router.add("PUT", "/api/user/learning-preferences", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_update_learning_preferences(db, &req))
    })
    // Data management API (from handlers_data.ch)
    srv.router.add("GET", "/api/user/export", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_export_data(db, &req))
    })
    srv.router.add("DELETE", "/api/user/data/:type", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var type_sv = segments.at_ref(3)
            var data_type = type_sv.to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_delete_data(db, &data_type, &req))
        } else {
            var body = std::string("{\"error\":\"missing type parameter\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("DELETE", "/api/user/account", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_delete_account(db, &req))
    })
    srv.router.add("POST", "/api/user/deactivate", ||(req) => {
        // H14: writes learner_settings and deletes auth_sessions for "demo"
        // when no session resolves. Account state changes are not anonymous.
        var db = request_db()
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_deactivate_account(db, &req))
    })
    srv.router.add("POST", "/api/user/reactivate", ||(req) => {
        // H14: the matching upsert writes learner_settings on a fresh DB even
        // though the probe only saw it change an existing row. Gate it too.
        var db = request_db()
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_reactivate_account(db, &req))
    })
    // Progress sharing (from handlers_data.ch)
    srv.router.add("POST", "/api/progress/share", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_share_progress(db, &req))
    })
    srv.router.add("GET", "/api/progress/shared/:token", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var token_sv = segments.at_ref(3)
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_shared_progress(db, token_sv))
        } else {
            var body = std::string("{\"error\":\"missing token\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("POST", "/api/progress/import", ||(req) => {
        // H14: an import inserts concept_states / review_items under "demo".
        // G13's one-shot guest takeover is a separate feature and is untouched.
        var db = request_db()
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_import_progress(db, &mut req))
    })
    srv.router.add("GET", "/api/user/:username", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_public_profile(db, &req))
    })
    // ---- Knowledge Health API (1.5.20) ----
    srv.router.add("GET", "/api/health/knowledge", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_knowledge_health(db, &req))
    })
    srv.router.add("GET", "/api/health/knowledge/per-module", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_knowledge_health_per_module(db, &courses_dir, &req))
    })
    srv.router.add("GET", "/api/health/knowledge/projection", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_knowledge_projection(db, &req))
    })
    // ---- Course Enrollment API ----
    srv.router.add("POST", "/api/courses/:courseId/enroll", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_enroll_course(db, &req))
    })
    srv.router.add("GET", "/api/enrollments", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_enrollments(db, &req))
    })
    // ---- Onboarding (Agent 1) ----
    srv.router.add("GET", "/onboarding", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_onboarding_page(&req))
    })
    srv.router.add("POST", "/api/onboarding/complete", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_onboarding_complete(db, &req))
    })
    srv.router.add("GET", "/api/onboarding/check", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_check_onboarding(db, &req))
    })
    // G1: verified-bank diagnostic items + the real answer scorer. Additive;
    // the old /api/courses/:id/assess route keeps its shape.
    srv.router.add("GET", "/api/onboarding/diagnostic", ||(req) => {
        var db = request_db()
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_onboarding_diagnostic(db, &courses_dir, &req))
    })
    srv.router.add("POST", "/api/onboarding/score", ||(req) => {
        var db = request_db()
        var courses_dir = underlayer_web::request_courses_dir()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_onboarding_score(db, &courses_dir, &mut req))
    })
    // ---- Profile stats & courses (Agent 5) ----
    srv.router.add("GET", "/api/user/:username/stats", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var username = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_profile_stats(db, &username, &req))
        } else {
            var body = std::string("{\"error\":\"missing username\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/api/user/:username/courses", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var username = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_profile_courses(db, &username, &req))
        } else {
            var body = std::string("{\"error\":\"missing username\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Content Feedback API ----
    srv.router.add("POST", "/api/feedback", ||(req) => {
        var db = request_db()
        // RATE LIMITED.
        // 120 per 5 min.
        // It writes into a table a HUMAN reads -- the corrections queue -- so an
        // unbounded writer fills it with noise and makes the queue unworkable
        var gate = underlayer_web::rate_limit_feedback(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_submit_feedback(db, &req))
    })
    srv.router.add("GET", "/api/feedback/stats", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_feedback_stats(db, &req))
    })
    srv.router.add("GET", "/api/feedback/admin", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_admin_feedback(db, &req))
    })
    srv.router.add("GET", "/api/feedback/admin/reports", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_admin_reports(db, &req))
    })
    srv.router.add("POST", "/api/feedback/report-exercise", ||(req) => {
        var db = request_db()
        // RATE LIMITED: 120 per 5 min.  Same queue as /api/feedback: a human has to triage it
        var gate = underlayer_web::rate_limit_report_exercise(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_report_exercise(db, &req))
    })
    srv.router.add("GET", "/api/feedback/concept/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.at_ref(3).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_concept_feedback(db, &concept_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing concept id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("PUT", "/api/feedback/:id/status", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var feedback_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_update_feedback_status(db, &feedback_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing feedback id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Notifications API ----
    srv.router.add("GET", "/api/notifications", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_notifications(db, &req))
    })
    srv.router.add("GET", "/api/notifications/unread-count", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_unread_count(db, &req))
    })
    srv.router.add("POST", "/api/notifications/read-all", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_mark_all_read(db, &req))
    })
    srv.router.add("POST", "/api/notifications/:id/read", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_mark_read(db, &req))
    })
    srv.router.add("DELETE", "/api/notifications/:id", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_delete_notification(db, &req))
    })
    // ---- Course Prerequisites API ----
    srv.router.add("GET", "/api/courses/:courseId/prerequisites", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_prerequisites(db, &course_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("POST", "/api/courses/:courseId/prerequisites", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_add_prerequisite(db, &course_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("DELETE", "/api/courses/:courseId/prerequisites/:requiredId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.at_ref(2).to_string()
            var required_id = segments.at_ref(3).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_remove_prerequisite(db, &course_id, &required_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course or required id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/api/courses/:courseId/can-enroll", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_can_enroll(db, &course_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("POST", "/api/courses/:courseId/assess", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_skill_assessment(db, &course_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/api/courses/:courseId/assessment", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_assessment(db, &course_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Course Reviews API ----
    srv.router.add("POST", "/api/courses/:courseId/reviews", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_submit_review(db, &course_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/api/courses/:courseId/reviews", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_course_reviews(db, &course_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/api/courses/:courseId/rating", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_course_rating_summary(db, &course_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("PUT", "/api/reviews/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var review_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_update_review(db, &review_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing review id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("DELETE", "/api/reviews/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var review_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_delete_review(db, &review_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing review id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // A SESSION IS REQUIRED, and it is a smaller change than it looks: this was
    // an unauthenticated vote with no dedupe, so `curl` in a loop on any
    // review id moved `helpful_count` without limit -- and the count is what
    // the course landing page shows a visitor deciding whether to read the
    // review.  A free account still allows unlimited votes, so this is NOT
    // presented as the complete fix; the dedupe is the remaining half and it
    // needs a per-learner "already voted" column, which is a schema change
    // rather than a gate.  What this does stop is a vote with no identity at
    // all.  See docs/audit-2026-10-02-production.md.
    srv.router.add("POST", "/api/reviews/:id/helpful", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var anon = string("unauthorized")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &anon))

        }
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var review_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_mark_review_helpful(db, &review_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing review id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Bookmarks API ----
    srv.router.add("POST", "/api/bookmarks", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_add_bookmark(db, &req))
    })
    srv.router.add("DELETE", "/api/bookmarks/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var concept_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_remove_bookmark(db, &concept_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing concept id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/api/bookmarks", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_bookmarks(db, &req))
    })
    srv.router.add("GET", "/api/bookmarks/check/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.at_ref(3).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_check_bookmark(db, &concept_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing concept id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- Certificates API ----
    srv.router.add("POST", "/api/certificates", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_issue_certificate(db, &courses_dir, &req))
    })
    srv.router.add("GET", "/api/certificates", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_certificates(db, &req))
    })
    srv.router.add("GET", "/api/certificates/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var cert_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_certificate(db, &cert_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing certificate id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/certificates/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            var cert_id = segments.at_ref(1).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_certificate_page(db, &cert_id, &req))
        } else {
            var body = std::string("missing certificate id")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_status_text(400u, &body))
        }
    })
    // ---- Analytics Dashboard ----
    srv.router.add("GET", "/analytics", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_analytics_page(db, &req))
    })
    srv.router.add("GET", "/api/analytics/overview", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_analytics_overview_api(db, &req))
    })
    srv.router.add("GET", "/analytics/:courseId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            var course_id = segments.at_ref(1).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_course_analytics_page(db, &course_id, &req))
        } else {
            var body = std::string("missing course id")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_status_text(400u, &body))
        }
    })
    // ---- Learning Path Visualization ----
    srv.router.add("GET", "/api/courses/:courseId/path", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_learning_path_api(db, &courses_dir, &course_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/courses/:courseId/path", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(1).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_learning_path_page(db, &courses_dir, &course_id, &req))
        } else {
            var body = std::string("missing course id")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_status_text(400u, &body))
        }
    })
    // ---- Help & Guide Pages: served by the web::App as pre-rendered routes (see the App below) ----
    // ---- Feature Pages (bookmarks, notes, planner, achievements, streaks, notifications, certificates) ----
    //
    // ALL SEVEN ARE GATED, and the gate is here rather than inside each page's
    // builder so the list of gated pages is a list you can read in one place.
    //
    // These seven render a SHELL -- nav, headings, empty containers -- and then
    // fetch their data client-side from endpoints that all require a bearer
    // token and all answer 401 without one.  So an anonymous visitor got a page
    // that LOOKED like their bookmarks/notes/streaks and then filled it with
    // nothing, because every request behind it failed.  The failure was invisible
    // from outside: HTTP 200, correct headings, an empty list.
    //
    // Gating them server-side makes the answer true before any script runs, which
    // is the same rule the onboarding banner follows by shipping `hidden`.  It
    // also means the reader is told WHY, instead of being left to wonder whether
    // an empty account is normal.
    //
    // `next` is the page they asked for, so signing in brings them back to it
    // rather than to the home page.
    srv.router.add("GET", "/bookmarks", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/bookmarks")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::redirect_to_login(&gate_path))

        }
        var html = underlayer_web::render_bookmarks_page()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_html(&html))
    })
    srv.router.add("GET", "/notes", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/notes")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::redirect_to_login(&gate_path))

        }
        var html = underlayer_web::render_notes_page()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_html(&html))
    })
    srv.router.add("GET", "/study-plans", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/study-plans")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::redirect_to_login(&gate_path))

        }
        var html = underlayer_web::render_study_plans_page()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_html(&html))
    })
    srv.router.add("GET", "/achievements", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/achievements")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::redirect_to_login(&gate_path))

        }
        var html = underlayer_web::render_achievements_page()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_html(&html))
    })
    srv.router.add("GET", "/streaks", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/streaks")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::redirect_to_login(&gate_path))

        }
        var html = underlayer_web::render_streaks_page()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_html(&html))
    })
    srv.router.add("GET", "/notifications", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/notifications")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::redirect_to_login(&gate_path))

        }
        var html = underlayer_web::render_notifications_page()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_html(&html))
    })
    srv.router.add("GET", "/certificates", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/certificates")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::redirect_to_login(&gate_path))

        }
        var html = underlayer_web::render_certificates_page()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_html(&html))
    })
    // ---- Learning Loop API ----
    // courses_dir is passed so the handler can check the concept id against the
    // course manifest before writing a row. See handle_learning_view.
    // `|&db|` BY REFERENCE, like every other handler route here (see
    // /api/review/start directly above). The closure was by-value `|db|` and
    // that is the exact pairing 2.2.46 records: a by-value capture copied the
    // DbClient, so the handler was handed a struct whose sqlite_handle was not
    // the live connection and every statement prepared on it failed with
    // SQLITE_MISUSE. The type error that this line now reports is the compiler
    // catching it at build time rather than at request time.
    srv.router.add("POST", "/api/learning/view", ||(req) => {
        var courses_dir = underlayer_web::request_courses_dir()
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_learning_view(db, &courses_dir, &req))
    })
    // ---- Notes API ----
    srv.router.add("GET", "/api/notes", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_notes(db, &req))
    })
    srv.router.add("POST", "/api/notes", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_create_note(db, &req))
    })
    srv.router.add("PUT", "/api/notes/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var note_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_update_note(db, &note_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing note id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("DELETE", "/api/notes/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var note_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_delete_note(db, &note_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing note id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/api/notes/concept/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.at_ref(3).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_concept_notes(db, &concept_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing concept id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("GET", "/api/notes/search", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_search_notes(db, &req))
    })
    // ---- Achievements API ----
    srv.router.add("GET", "/api/achievements", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_achievements(db, &req))
    })
    srv.router.add("POST", "/api/achievements/check", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_check_achievements(db, &req))
    })
    srv.router.add("GET", "/api/achievements/count", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_achievement_count(db, &req))
    })
    // ---- Streaks API ----
    srv.router.add("GET", "/api/streaks", ||(req) => {
        var db = request_db()
        // I9: a streak is personal. The handler's "demo" fallback used to give
        // every signed-out visitor the same invented streak.
        if(!underlayer_web::has_session(db, &req)) {
            var msg = string("Sign in to see your data")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &msg))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_streak(db, &req))
    })
    srv.router.add("POST", "/api/streaks/activity", ||(req) => {
        // H14: writes daily_activity + learning_streaks for the shared demo id.
        var db = request_db()
        var gate = require_session_in_release(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return underlayer_web::deliver_with_learner(request_db(), &req, refusal)
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_record_activity(db, &req))
    })
    srv.router.add("GET", "/api/streaks/weekly", ||(req) => {
        var db = request_db()
        // I9: a per-day activity calendar is the visitor's own history.
        if(!underlayer_web::has_session(db, &req)) {
            var msg = string("Sign in to see your data")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_error(401u, &msg))
        }
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_weekly_activity(db, &req))
    })
    // ---- Study Planner API ----
    srv.router.add("POST", "/api/study-plans", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_create_study_plan(db, &req))
    })
    srv.router.add("GET", "/api/study-plans", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_get_study_plans(db, &req))
    })
    srv.router.add("PUT", "/api/study-plans/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var plan_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_update_study_plan(db, &plan_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing plan id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    srv.router.add("DELETE", "/api/study-plans/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var plan_id = segments.at_ref(2).to_string()
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_delete_study_plan(db, &plan_id, &req))
        } else {
            var body = std::string("{\"error\":\"missing plan id\"}")
            return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::send_json_status(400u, &body))
        }
    })
    // ---- G2: Today ----
    srv.router.add("GET", "/today", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_today_page(db, &req))
    })
    srv.router.add("GET", "/api/today", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_today_status(db, &req))
    })
    srv.router.add("POST", "/api/today/plan", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_today_plan(db, &req))
    })
    srv.router.add("POST", "/api/today/complete", ||(req) => {
        var db = request_db()
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_today_complete(db, &req))
    })
    // ---- G6: installable web assets (explicit routes ahead of catch-all) ----
    srv.router.add("GET", "/manifest.webmanifest", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_manifest(&req))
    })
    srv.router.add("GET", "/sw.js", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_service_worker(&req))
    })
    srv.router.add("GET", "/icons/:name", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_pwa_icon(&req))
    })
    // ---- Delivery: one web::App owns the page layer ----
    //
    // WHY AN APP AND NOT ONE ROUTE PER PAGE.  The six guide pages are the same for
    // every reader, so they are PRE-RENDERED (`app.page`): `build()` renders each
    // one once, minifies its inline CSS, moves its page JS into a content-hashed
    // per-route chunk (`assets/chunk.<hash>.js`), writes a `.gz` sibling, and the
    // framework serves the frozen bytes with `no-cache` + ETag + 304.  A request
    // for /help runs no handler at all.
    //
    // Everything else stays per-request, and keeps the response it already built.
    // The App is mounted behind one catch-all, so the 187 routes registered above
    // keep their exact URLs and their dispatch order; the App only ever sees what
    // they did not claim (/help-style pages, /assets/*, and the 404).
    //
    // `set_minify` shrinks the emitted chunks, `set_gzip` precompresses the frozen
    // artifacts (the honest `Accept-Encoding` negotiation lives in the site), and
    // `finish()` is what actually writes them Ã¢â‚¬â€ `build()` only compiles.
    var app = web::App.make("build/site", "app", "assets")
    app.set_minify(true)
    app.set_gzip(true)
    app.page("/help", underlayer_web::page_help)
    app.page("/shortcuts", underlayer_web::page_shortcuts)
    app.page("/faq", underlayer_web::page_faq)
    app.page("/about", underlayer_web::page_about)
    app.page("/terms", underlayer_web::page_terms)
    app.page("/privacy", underlayer_web::page_privacy)
    app.not_found(underlayer_web::page_not_found)
    // Per-request pages. `no-store` is the honest policy: these renders carry the
    // reader's own state (nav, enrol button, onboarding banner), so a shared cache
    // must not keep them. `set_dynamic_gzip` compresses them on the way out.

    app.set_dynamic_gzip(true)
    if(!app.build()) {
        var build_err = std::string("[underlayer] web::App build failed: ")
        var err_view = app.error_message()
        build_err.append_view(&err_view)
        underlayer_core::log_line(&build_err)
        return 1
    }
    if(!app.finish()) {
        var finish_err = std::string("[underlayer] web::App could not write build/site")
        underlayer_core::log_line(&finish_err)
        return 1
    }
    unsafe { web::install(&raw mut app) }
    // B5: the external pre-paint theme bootstrap. Must be an EXPLICIT route
    // ahead of the catch-all below: the frozen web::App has no artifact at this
    // path, so a catch-all hit would serve the 404 and the theme would flash.
    // The JS bytes and the pinned hash live in content/src/theme_boot.ch; this
    // route only answers them, with the same CSP/ETag/request-id as everything
    // else. No caller-supplied header influences the response.
    srv.router.add("GET", "/assets/theme-boot.js", ||(req) => {
        return underlayer_web::deliver_with_learner(request_db(), &req, underlayer_web::handle_theme_boot(&req))
    })
    // The catch-all: one registration per method, last in the table, so every
    // explicit route above keeps first refusal. `web::serve_request` answers from
    // the frozen site (pages, assets with their immutable cache headers, 404).
    srv.router.add("GET", "/:path*", ||(req) => {
        return underlayer_web::deliver_web_request(request_db(), req)
    })
    srv.router.add("HEAD", "/:path*", ||(req) => {
        return underlayer_web::deliver_web_request(request_db(), req)
    })
    // ---- Start server ----
    var listen_msg = std::string("[underlayer] Server running at http://localhost:")
    listen_msg.append_string(&underlayer_core::u32_to_string(port))
    underlayer_core::log_line(&listen_msg)
    var courses_msg = std::string("[underlayer] Courses dir: ")
    courses_msg.append_string(&cfg.courses_dir)
    underlayer_core::log_line(&courses_msg)
    srv.serve()

    // `serve()` returns only after the accept loop stops and the worker pool
    // has drained queued/in-flight requests, so the DB handle is safe to close
    // here. Any work still running past the 30 s body timeout is bounded by the
    // upstream server, not by an invented sleep in this file.
    underlayer_db::close(&raw db)
    var shutdown_done = std::string("[underlayer] shutdown complete")
    underlayer_core::log_line(&shutdown_done)
    return 0
}


