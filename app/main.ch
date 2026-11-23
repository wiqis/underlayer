// Underlayer — Server entrypoint
// Phase 1: Minimal working platform serving static courses.
using std::string
using std::string_view

// ---- Process-wide state ------------------------------------------------
//
// The router stores handlers as `Send + Sync + 'static`, so a handler cannot
// capture the `DbClient` or the courses directory by reference -- and a
// `DbClient` holds the live SQLite handle, which is not `Send`.  There is one of
// each per process, so they live here and are reached through the two accessors
// below.  Those two `unsafe` blocks are the whole of the process-wide state
// handling in the application; every route stays safe and captures nothing.
//
// The value is a POINTER, not a copy: copying a `DbClient` would copy the
// `http::Client`'s mutex and hand out a second view of one connection, which is
// exactly the by-value-capture bug recorded at the /api/exercises/submit route.
// A pointer to the `DbClient` main() owns, and a copy of the courses directory.
// Storing the address is deliberate: copying a `DbClient` would copy the
// `http::Client`'s mutex and hand out a second view of one connection.
@never_destructed
var g_db : *underlayer_db::DbClient
// The courses directory, as a fixed buffer rather than a `string` global: a
// zero-initialised `@never_destructed` global is not a constructed value, and a
// `string` global assigned at startup read back EMPTY at request time (measured:
// every manifest path came out as "/<course>/manifest.json", i.e. with an empty
// prefix).  A char array has no constructor to be missing.
comptime const COURSES_DIR_MAX : size_t = 512
@never_destructed
var g_courses_buf : [COURSES_DIR_MAX]char
@never_destructed
var g_courses_len : size_t

// Fill the two values once, before the server starts accepting.
func set_process_state(dbv : *underlayer_db::DbClient, courses : &string) {
    unsafe {
        g_db = dbv
        var n = courses.size()
        if(n >= COURSES_DIR_MAX) { n = COURSES_DIR_MAX - 1 }
        var i : size_t = 0
        while(i < n) {
            g_courses_buf[i] = courses.at(i)
            i = i + 1
        }
        g_courses_buf[n] = 0
        g_courses_len = n
    }
}

// The process's database handle.  Valid for the life of the process.
public func request_db() : *underlayer_db::DbClient {
    return unsafe(g_db)
}

// The courses directory, as a value: handlers take `&string` and must not hold a
// view into the global.
public func request_courses_dir() : string {
    var out = std::string()
    var n = unsafe(g_courses_len)
    var i : size_t = 0
    while(i < n) {
        out.append(unsafe(g_courses_buf[i]))
        i = i + 1
    }
    return out
}
public func main() : int {
    // ---- Config & DB ----
    var cfg = underlayer_core::load_config()
    var port = cfg.port
    var db_url = cfg.db_url.copy()
    var db_token = cfg.db_token.copy()

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
    var srv = server.Server(cfg_server)

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
        // See web/src/rate_limit.ch.
        // See web/src/rate_limit.ch.

        return underlayer_web::handle_create_learner(db, &req)
    })
    srv.router.add("GET", "/api/learners/:learnerId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var learner_id = segments.at_ref(2)
            return underlayer_web::handle_get_learner(db, learner_id, &req)
        } else {
            var body = std::string("{\"error\": \"missing learner id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Health check ----
    srv.router.add("GET", "/api/health", ||(req) => {
        return underlayer_web::handle_health(&req)
    })

    // Review page (HTML UI)
    srv.router.add("GET", "/review", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_review_page(db, &courses_dir, &req)
    })
    // Progress page (HTML UI)
    srv.router.add("GET", "/progress", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_progress_page(db, &courses_dir, &req)
    })
    // Dashboard page (7.2.4, 7.2.5, 1.5.20)
    srv.router.add("GET", "/dashboard", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_dashboard(db, &courses_dir, &req)
    })
    // Knowledge Health page. Server-rendered from the learner's own rows, so it
    // works with JS off; gated because unsigned it would be four zeroes.
    srv.router.add("GET", "/health", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_knowledge_health_page(db, &courses_dir, &req)
    })
    // Course listing
    srv.router.add("GET", "/api/courses", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::handle_list_courses(&courses_dir, &req)
    })
    // Filter Courses (7.1.7)
    srv.router.add("GET", "/api/courses/all", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::handle_filter_courses(&courses_dir, &req)
    })
    // Course detail
    srv.router.add("GET", "/api/courses/:courseId", ||(req) => {
        var courses_dir = request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2)
            return underlayer_web::handle_get_course(&courses_dir, course_id, &req)
        } else {
            var body = std::string("{\"error\": \"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // Lesson viewer via API
    srv.router.add("GET", "/api/courses/:courseId/lessons/:conceptId", ||(req) => {
        var courses_dir = request_courses_dir()
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
            return underlayer_web::handle_lesson(&courses_dir, course_id, concept_id, &req)
        } else {
            var body = std::string("{\"error\": \"missing course or concept id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Review API ----
    srv.router.add("GET", "/api/review/start", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_review_start(db, &courses_dir, &req)
    })
    srv.router.add("POST", "/api/review/submit", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_review_submit(db, &mut req)
    })
    srv.router.add("POST", "/api/review/end", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_review_end(db, &req)
    })
    // ---- Due Items ----
    srv.router.add("GET", "/api/review/due", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_review_due(db, &courses_dir, &req)
    })
    // ---- Session Recommendations (1.2.25) ----
    srv.router.add("GET", "/api/review/recommendations", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_recommendations(db, &req)
    })
    // ---- Time-of-Day Recommendation (1.2.27) ----
    srv.router.add("GET", "/api/review/time-recommendation", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_time_recommendation(db, &req)
    })
    // ---- Search (7.1.6) ----
    srv.router.add("GET", "/api/search", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::handle_search(&courses_dir, &req)
    })
    // Concept search: titles, descriptions, module names and course titles
    // across all courses. Additive — /api/search's response shape is a
    // shipped contract and is left alone.
    srv.router.add("GET", "/api/search/concepts", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::handle_search_concepts(&courses_dir, &req)
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
        return underlayer_web::handle_recent_history(db, &req)
    })
    // ---- Progress API ----
    srv.router.add("GET", "/api/progress", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_progress(db, &courses_dir, &req)
    })
    // ---- What am I doing: courses in progress, coverage, and the exercises
    // this learner got wrong (4.4.3).  One payload because /dashboard draws
    // all three at once and three round trips would make it flash.
    // Deliberately NOT /api/progress/overview: that path is already claimed by
    // the /api/progress/:courseId route above and would be swallowed by it.
    srv.router.add("GET", "/api/me/overview", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_my_overview(db, &courses_dir, &req)
    })
    // ---- Which quiz did I fail.  The same list without the course summary. ----
    srv.router.add("GET", "/api/exercises/failures", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_exercise_failures(db, &req)
    })
    // ---- Progress Export (6.1.7) ----
    srv.router.add("GET", "/api/progress/export", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_progress_export(db, &req)
    })
    // ---- Session Analytics (6.2.1) ----
    srv.router.add("GET", "/api/analytics/sessions", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_analytics(db, &req)
    })
    // ---- Concept Analytics (6.2.2) ----
    srv.router.add("GET", "/api/analytics/concept/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.at_ref(3)
            var course_id = string("elf")
            return underlayer_web::handle_concept_analytics(db, concept_id, &req)
        } else {
            var body = std::string("{\"error\": \"missing concept id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Course Analytics (6.2.3) ----
    srv.router.add("GET", "/api/analytics/course/:courseId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.at_ref(3)
            return underlayer_web::handle_course_analytics(db, course_id, &req)
        } else {
            var body = std::string("{\"error\": \"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Difficulty Analytics (6.2.8) ----
    srv.router.add("GET", "/api/analytics/difficulty", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_difficulty_analytics(db, &req)
    })
    // ---- Error Analytics (6.2.9) ----
    srv.router.add("GET", "/api/analytics/errors", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_error_analytics(db, &req)
    })
    // ---- Engagement Analytics (6.2.13) ----
    srv.router.add("GET", "/api/analytics/engagement", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_engagement_analytics(db, &req)
    })
    // ---- Velocity Analytics (6.2.14) ----
    srv.router.add("GET", "/api/analytics/velocity", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_velocity_analytics(db, &req)
    })
    // ---- Learning Analytics (P2 6.2.4-6.2.7, 6.2.10-6.2.12, 6.2.15) ----
    srv.router.add("GET", "/api/analytics/temporal", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_temporal_analytics(db, &req)
    })
    srv.router.add("GET", "/api/analytics/retention", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_retention_analytics(db, &req)
    })
    srv.router.add("GET", "/api/analytics/dropoff", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_dropoff_analytics(db, &req)
    })
    srv.router.add("GET", "/api/analytics/funnel", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_funnel_analytics(db, &req)
    })
    srv.router.add("GET", "/api/analytics/comparative", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_comparative_analytics(db, &req)
    })
    srv.router.add("GET", "/api/analytics/platform", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_platform_analytics(db, &req)
    })
    srv.router.add("GET", "/api/analytics/cohorts", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_cohort_analytics(db, &req)
    })
    srv.router.add("GET", "/api/analytics/devices", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_device_analytics(db, &req)
    })
    // ---- Course Progress API ----
    srv.router.add("GET", "/api/progress/:courseId", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_course_progress(db, &courses_dir, &req)
    })
    // ---- Learning Goals (6.1.5) ----
    // GET was missing: the feature could write a goal and never read one back.
    srv.router.add("GET", "/api/goals", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_goals(db, &req)
    })
    srv.router.add("POST", "/api/goals", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_set_goal(db, &mut req)
    })
    srv.router.add("DELETE", "/api/goals", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_delete_goal(db, &req)
    })
    // ---- Weakness Dashboard (1.4.21) ----
    srv.router.add("GET", "/api/weaknesses", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_weakness_dashboard(db, &req)
    })
    // ---- Weakness Export (1.4.23) ----
    srv.router.add("GET", "/api/weaknesses/export", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_weakness_export(db, &req)
    })
    // ---- Weakness Compare (1.4.22) ----
    srv.router.add("GET", "/api/weaknesses/compare", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_weakness_compare(db, &req)
    })
    // ---- Weakness Alerts (1.4.24) ----
    srv.router.add("GET", "/api/weaknesses/alerts", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_weakness_alerts(db, &req)
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
        var courses_dir = request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2)
            // An empty concept id makes the handler omit the breadcrumbs and the
            // prev/next block, which is exactly the difference wanted here.
            var no_concept = std::string_view("")
            return underlayer_web::handle_navigation(&courses_dir, course_id, &no_concept, &req)
        } else {
            var body = std::string("{\"error\": \"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/api/navigation/:courseId/:conceptId", ||(req) => {
        var courses_dir = request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.at_ref(2)
            var concept_id = segments.at_ref(3)
            return underlayer_web::handle_navigation(&courses_dir, course_id, concept_id, &req)
        } else {
            var body = std::string("{\"error\": \"missing course or concept id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Nav Status (P2 7.1.13 progress indicator, P2 7.1.15 due indicator) ----
    // Takes ?course_id= because the bar it feeds is drawn by the per-course
    // landing nav; it used to report elf's numbers on every course page.
    srv.router.add("GET", "/api/nav-status", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_nav_status(db, &courses_dir, &req)
    })
    // ---- Nav Search / Quick Jump (P2 7.1.10 command palette) ----
    srv.router.add("GET", "/api/nav-search", ||(req) => {
        return underlayer_web::handle_nav_search(&req)
    })

    // ---- FSRS Settings (1.1.24-1.1.28) ----
    srv.router.add("POST", "/api/fsrs/optimize", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_fsrs_optimize(db, &req)
    })
    srv.router.add("POST", "/api/fsrs/reset", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_fsrs_reset(db, &req)
    })
    srv.router.add("GET", "/api/fsrs/export", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_fsrs_export(db, &req)
    })
    srv.router.add("POST", "/api/fsrs/import", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_fsrs_import(db, &mut req)
    })
    // ---- Session History (1.2.21, 1.2.22) ----
    srv.router.add("GET", "/api/sessions", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_history(db, &req)
    })
    // ---- Session Detail (1.2.22) ----
    srv.router.add("GET", "/api/sessions/:sessionId", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_detail(db, &req)
    })
    srv.router.add("GET", "/api/session/detail", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_detail(db, &req)
    })
    // ---- Session Management (1.2.9-1.2.13) ----
    srv.router.add("POST", "/api/session/pause", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_pause(db, &req)
    })
    srv.router.add("POST", "/api/session/resume", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_resume(db, &req)
    })
    srv.router.add("POST", "/api/session/abort", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_abort(db, &req)
    })
    srv.router.add("POST", "/api/session/undo", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_undo(db, &req)
    })
    srv.router.add("POST", "/api/session/skip", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_session_skip(db, &req)
    })
    // ---- Bulk Exercise Import API ----
    srv.router.add("POST", "/api/exercises/import", ||(req) => {
        var db = request_db()
        return underlayer_web::refuse_exercise_import(db, &req)
    })
    srv.router.add("POST", "/api/exercises/seed", ||(req) => {
        var db = request_db()
        return underlayer_web::refuse_exercise_seed(db, &req)
    })
    srv.router.add("GET", "/api/exercises/stats", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_exercise_stats(db, &req)
    })
    // ---- Exercise API (4.1.1-4.1.5, 4.2.1-4.2.5) ----
    srv.router.add("GET", "/api/exercises/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var concept_id = segments.at_ref(2)
            return underlayer_web::handle_get_exercises(db, concept_id, &req)
        } else {
            var body = std::string("{\"error\": \"missing concept id\"}")
            return underlayer_web::send_json_status(400u, &body)
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
            return refusal
        }
        return underlayer_web::handle_exercise_submit(db, &mut req)
    })
    srv.router.add("GET", "/api/exercises/hint", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_exercise_hint(db, &req)
    })
    // Course index — /courses. Registered BEFORE /courses/:courseId so the
    // exact path wins over the parameterised one. This is the page every
    // lesson's "All courses" back-link points at, 42 times across 32 files,
    // and it did not exist until now; tools/link_check.py is what stops that
    // from being true again.
    srv.router.add("GET", "/courses", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::handle_courses_page(&courses_dir, &req)
    })
    // Learning path — the three routes through the collection. Distinct from
    // /courses/:courseId/path, which is the per-course dependency graph.
    srv.router.add("GET", "/learning-path", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::handle_learning_path_index(&courses_dir, &req)
    })
    // Search — concept search, server-rendered from ?q=
    srv.router.add("GET", "/search", ||(req) => {
        var courses_dir = request_courses_dir()
        return underlayer_web::handle_search_page(&courses_dir, &req)
    })
    // Course landing page
    srv.router.add("GET", "/courses/:courseId", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            var course_id = segments.at_ref(1)
            return underlayer_web::handle_course_landing(db, &courses_dir, course_id, &req)
        } else {
            return underlayer_web::handle_home(&req)
        }
    })
    // Lesson viewer via URL path
    srv.router.add("GET", "/courses/:courseId/lessons/:conceptId", ||(req) => {
        var courses_dir = request_courses_dir()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.at_ref(1)
            var concept_id = segments.at_ref(3)
            return underlayer_web::handle_lesson(&courses_dir, course_id, concept_id, &req)
        } else {
            var body = std::string("Not found")
            return underlayer_web::send_status_text(404u, &body)
        }
    })
    // Static file serving for course output (HTML, CSS, JS, images)
    srv.router.add("GET", "/courses/*", ||(req) => {
        var courses_dir = request_courses_dir()
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
            return underlayer_web::handle_static_file(&courses_dir, &path)
        } else {
            // Try course landing page
            var segments = underlayer_core::path_segments(&path)
            if(segments.size() >= 2) {
                var course_id = segments.at_ref(1)
                return underlayer_web::handle_course_landing(db, &courses_dir, course_id, &req)
            } else {
                return underlayer_web::handle_home(&req)
            }
        }
    })
    // Home page
    srv.router.add("GET", "/", ||(req) => {
        return underlayer_web::handle_home(&req)
    })

    // ---- Account management routes (Section 16) ----
    // Auth pages
    srv.router.add("GET", "/login", ||(req) => {
        return underlayer_web::handle_login_page(&req)
    })
    srv.router.add("GET", "/register", ||(req) => {
        return underlayer_web::handle_register_page(&req)
    })
    srv.router.add("GET", "/forgot-password", ||(req) => {
        return underlayer_web::handle_forgot_password_page(&req)
    })
    srv.router.add("GET", "/reset-password", ||(req) => {
        return underlayer_web::handle_reset_password_page(&req)
    })
    // Settings page
    srv.router.add("GET", "/settings", ||(req) => {
        return underlayer_web::handle_settings_page(&req)
    })
    srv.router.add("GET", "/components", ||(req) => {
        return underlayer_web::handle_components_demo_page(&req)
    })
    srv.router.add("GET", "/u/:username", ||(req) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            return underlayer_web::handle_profile_page(&req)
        } else {
            var body = std::string("Not found")
            return underlayer_web::send_status_text(404u, &body)
        }
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
            return refusal
        }
        return underlayer_web::handle_register(db, &mut req)
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
            return refusal
        }
        return underlayer_web::handle_login(db, &mut req)
    })
    srv.router.add("POST", "/api/auth/logout", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_logout(db, &req)
    })
    srv.router.add("GET", "/api/auth/me", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_me(db, &req)
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
            return refusal
        }
        return underlayer_web::handle_forgot_password(db, &mut req)
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
            return refusal
        }
        return underlayer_web::handle_reset_password(db, &mut req)
    })
    srv.router.add("POST", "/api/auth/verify-email", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_verify_email(db, &mut req)
    })
    srv.router.add("GET", "/api/user/login-history", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_login_history(db, &req)
    })
    // Profile API (from handlers_profiles.ch)
    srv.router.add("GET", "/api/user/profile", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_profile(db, &req)
    })
    srv.router.add("PUT", "/api/user/profile", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_update_profile(db, &req)
    })
    // Settings API (from handlers_settings.ch)
    srv.router.add("GET", "/api/user/settings", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_settings(db, &req)
    })
    srv.router.add("PUT", "/api/user/settings", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_update_settings(db, &req)
    })
    srv.router.add("GET", "/api/user/learning-preferences", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_learning_preferences(db, &req)
    })
    srv.router.add("PUT", "/api/user/learning-preferences", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_update_learning_preferences(db, &req)
    })
    // Data management API (from handlers_data.ch)
    srv.router.add("GET", "/api/user/export", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_export_data(db, &req)
    })
    srv.router.add("DELETE", "/api/user/data/:type", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var type_sv = segments.at_ref(3)
            var data_type = type_sv.to_string()
            return underlayer_web::handle_delete_data(db, &data_type, &req)
        } else {
            var body = std::string("{\"error\":\"missing type parameter\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("DELETE", "/api/user/account", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_delete_account(db, &req)
    })
    srv.router.add("POST", "/api/user/deactivate", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_deactivate_account(db, &req)
    })
    srv.router.add("POST", "/api/user/reactivate", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_reactivate_account(db, &req)
    })
    // Progress sharing (from handlers_data.ch)
    srv.router.add("POST", "/api/progress/share", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_share_progress(db, &req)
    })
    srv.router.add("GET", "/api/progress/shared/:token", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var token_sv = segments.at_ref(3)
            return underlayer_web::handle_get_shared_progress(db, token_sv)
        } else {
            var body = std::string("{\"error\":\"missing token\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("POST", "/api/progress/import", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_import_progress(db, &mut req)
    })
    srv.router.add("GET", "/api/user/:username", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_public_profile(db, &req)
    })
    // ---- Knowledge Health API (1.5.20) ----
    srv.router.add("GET", "/api/health/knowledge", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_knowledge_health(db, &req)
    })
    srv.router.add("GET", "/api/health/knowledge/per-module", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_knowledge_health_per_module(db, &courses_dir, &req)
    })
    srv.router.add("GET", "/api/health/knowledge/projection", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_knowledge_projection(db, &req)
    })
    // ---- Course Enrollment API ----
    srv.router.add("POST", "/api/courses/:courseId/enroll", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_enroll_course(db, &req)
    })
    srv.router.add("GET", "/api/enrollments", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_enrollments(db, &req)
    })
    // ---- Onboarding (Agent 1) ----
    srv.router.add("GET", "/onboarding", ||(req) => {
        return underlayer_web::handle_onboarding_page(&req)
    })
    srv.router.add("POST", "/api/onboarding/complete", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_onboarding_complete(db, &req)
    })
    srv.router.add("GET", "/api/onboarding/check", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_check_onboarding(db, &req)
    })
    // ---- Profile stats & courses (Agent 5) ----
    srv.router.add("GET", "/api/user/:username/stats", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var username = segments.at_ref(2).to_string()
            return underlayer_web::handle_profile_stats(db, &username, &req)
        } else {
            var body = std::string("{\"error\":\"missing username\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/api/user/:username/courses", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var username = segments.at_ref(2).to_string()
            return underlayer_web::handle_profile_courses(db, &username, &req)
        } else {
            var body = std::string("{\"error\":\"missing username\"}")
            return underlayer_web::send_json_status(400u, &body)
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
            return refusal
        }
        return underlayer_web::handle_submit_feedback(db, &req)
    })
    srv.router.add("GET", "/api/feedback/stats", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_feedback_stats(db, &req)
    })
    srv.router.add("GET", "/api/feedback/admin", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_admin_feedback(db, &req)
    })
    srv.router.add("GET", "/api/feedback/admin/reports", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_admin_reports(db, &req)
    })
    srv.router.add("POST", "/api/feedback/report-exercise", ||(req) => {
        var db = request_db()
        // RATE LIMITED: 120 per 5 min.  Same queue as /api/feedback: a human has to triage it
        var gate = underlayer_web::rate_limit_report_exercise(db, &req)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return refusal
        }
        return underlayer_web::handle_report_exercise(db, &req)
    })
    srv.router.add("GET", "/api/feedback/concept/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.at_ref(3).to_string()
            return underlayer_web::handle_get_concept_feedback(db, &concept_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing concept id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("PUT", "/api/feedback/:id/status", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var feedback_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_update_feedback_status(db, &feedback_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing feedback id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Notifications API ----
    srv.router.add("GET", "/api/notifications", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_notifications(db, &req)
    })
    srv.router.add("GET", "/api/notifications/unread-count", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_unread_count(db, &req)
    })
    srv.router.add("POST", "/api/notifications/read-all", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_mark_all_read(db, &req)
    })
    srv.router.add("POST", "/api/notifications/:id/read", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_mark_read(db, &req)
    })
    srv.router.add("DELETE", "/api/notifications/:id", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_delete_notification(db, &req)
    })
    // ---- Course Prerequisites API ----
    srv.router.add("GET", "/api/courses/:courseId/prerequisites", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_get_prerequisites(db, &course_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("POST", "/api/courses/:courseId/prerequisites", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_add_prerequisite(db, &course_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("DELETE", "/api/courses/:courseId/prerequisites/:requiredId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.at_ref(2).to_string()
            var required_id = segments.at_ref(3).to_string()
            return underlayer_web::handle_remove_prerequisite(db, &course_id, &required_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course or required id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/api/courses/:courseId/can-enroll", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_can_enroll(db, &course_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("POST", "/api/courses/:courseId/assess", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_skill_assessment(db, &course_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/api/courses/:courseId/assessment", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_get_assessment(db, &course_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Course Reviews API ----
    srv.router.add("POST", "/api/courses/:courseId/reviews", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_submit_review(db, &course_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/api/courses/:courseId/reviews", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_get_course_reviews(db, &course_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/api/courses/:courseId/rating", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_course_rating_summary(db, &course_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("PUT", "/api/reviews/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var review_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_update_review(db, &review_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing review id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("DELETE", "/api/reviews/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var review_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_delete_review(db, &review_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing review id\"}")
            return underlayer_web::send_json_status(400u, &body)
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
            return underlayer_web::send_error(401u, &anon)

        }
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var review_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_mark_review_helpful(db, &review_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing review id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Bookmarks API ----
    srv.router.add("POST", "/api/bookmarks", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_add_bookmark(db, &req)
    })
    srv.router.add("DELETE", "/api/bookmarks/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var concept_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_remove_bookmark(db, &concept_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing concept id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/api/bookmarks", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_bookmarks(db, &req)
    })
    srv.router.add("GET", "/api/bookmarks/check/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.at_ref(3).to_string()
            return underlayer_web::handle_check_bookmark(db, &concept_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing concept id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Certificates API ----
    srv.router.add("POST", "/api/certificates", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_issue_certificate(db, &courses_dir, &req)
    })
    srv.router.add("GET", "/api/certificates", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_certificates(db, &req)
    })
    srv.router.add("GET", "/api/certificates/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var cert_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_get_certificate(db, &cert_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing certificate id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/certificates/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            var cert_id = segments.at_ref(1).to_string()
            return underlayer_web::handle_certificate_page(db, &cert_id, &req)
        } else {
            var body = std::string("missing certificate id")
            return underlayer_web::send_status_text(400u, &body)
        }
    })
    // ---- Analytics Dashboard ----
    srv.router.add("GET", "/analytics", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_analytics_page(db, &req)
    })
    srv.router.add("GET", "/api/analytics/overview", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_analytics_overview_api(db, &req)
    })
    srv.router.add("GET", "/analytics/:courseId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            var course_id = segments.at_ref(1).to_string()
            return underlayer_web::handle_course_analytics_page(db, &course_id, &req)
        } else {
            var body = std::string("missing course id")
            return underlayer_web::send_status_text(400u, &body)
        }
    })
    // ---- Learning Path Visualization ----
    srv.router.add("GET", "/api/courses/:courseId/path", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_learning_path_api(db, &courses_dir, &course_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing course id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/courses/:courseId/path", ||(req) => {
        var courses_dir = request_courses_dir()
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.at_ref(1).to_string()
            return underlayer_web::handle_learning_path_page(db, &courses_dir, &course_id, &req)
        } else {
            var body = std::string("missing course id")
            return underlayer_web::send_status_text(400u, &body)
        }
    })
    // ---- Help & Guide Pages ----
    srv.router.add("GET", "/help", ||(req) => {
        return underlayer_web::handle_help_page(&req)
    })
    srv.router.add("GET", "/shortcuts", ||(req) => {
        return underlayer_web::handle_shortcuts_page(&req)
    })
    srv.router.add("GET", "/faq", ||(req) => {
        return underlayer_web::handle_faq_page(&req)
    })
    srv.router.add("GET", "/about", ||(req) => {
        return underlayer_web::handle_about_page(&req)
    })
    srv.router.add("GET", "/terms", ||(req) => {
        return underlayer_web::handle_terms_page(&req)
    })
    srv.router.add("GET", "/privacy", ||(req) => {
        return underlayer_web::handle_privacy_page(&req)
    })
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
            return underlayer_web::redirect_to_login(&gate_path)

        }
        var html = underlayer_web::render_bookmarks_page()
        return underlayer_web::send_html(&html)
    })
    srv.router.add("GET", "/notes", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/notes")
            return underlayer_web::redirect_to_login(&gate_path)

        }
        var html = underlayer_web::render_notes_page()
        return underlayer_web::send_html(&html)
    })
    srv.router.add("GET", "/study-plans", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/study-plans")
            return underlayer_web::redirect_to_login(&gate_path)

        }
        var html = underlayer_web::render_study_plans_page()
        return underlayer_web::send_html(&html)
    })
    srv.router.add("GET", "/achievements", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/achievements")
            return underlayer_web::redirect_to_login(&gate_path)

        }
        var html = underlayer_web::render_achievements_page()
        return underlayer_web::send_html(&html)
    })
    srv.router.add("GET", "/streaks", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/streaks")
            return underlayer_web::redirect_to_login(&gate_path)

        }
        var html = underlayer_web::render_streaks_page()
        return underlayer_web::send_html(&html)
    })
    srv.router.add("GET", "/notifications", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/notifications")
            return underlayer_web::redirect_to_login(&gate_path)

        }
        var html = underlayer_web::render_notifications_page()
        return underlayer_web::send_html(&html)
    })
    srv.router.add("GET", "/certificates", ||(req) => {
        var db = request_db()
        if(!underlayer_web::has_session(db, &req)) {
            var gate_path = string("/certificates")
            return underlayer_web::redirect_to_login(&gate_path)

        }
        var html = underlayer_web::render_certificates_page()
        return underlayer_web::send_html(&html)
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
        var courses_dir = request_courses_dir()
        var db = request_db()
        return underlayer_web::handle_learning_view(db, &courses_dir, &req)
    })
    // ---- Notes API ----
    srv.router.add("GET", "/api/notes", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_notes(db, &req)
    })
    srv.router.add("POST", "/api/notes", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_create_note(db, &req)
    })
    srv.router.add("PUT", "/api/notes/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var note_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_update_note(db, &note_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing note id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("DELETE", "/api/notes/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var note_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_delete_note(db, &note_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing note id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/api/notes/concept/:conceptId", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.at_ref(3).to_string()
            return underlayer_web::handle_get_concept_notes(db, &concept_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing concept id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("GET", "/api/notes/search", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_search_notes(db, &req)
    })
    // ---- Achievements API ----
    srv.router.add("GET", "/api/achievements", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_achievements(db, &req)
    })
    srv.router.add("POST", "/api/achievements/check", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_check_achievements(db, &req)
    })
    srv.router.add("GET", "/api/achievements/count", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_achievement_count(db, &req)
    })
    // ---- Streaks API ----
    srv.router.add("GET", "/api/streaks", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_streak(db, &req)
    })
    srv.router.add("POST", "/api/streaks/activity", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_record_activity(db, &req)
    })
    srv.router.add("GET", "/api/streaks/weekly", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_weekly_activity(db, &req)
    })
    // ---- Study Planner API ----
    srv.router.add("POST", "/api/study-plans", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_create_study_plan(db, &req)
    })
    srv.router.add("GET", "/api/study-plans", ||(req) => {
        var db = request_db()
        return underlayer_web::handle_get_study_plans(db, &req)
    })
    srv.router.add("PUT", "/api/study-plans/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var plan_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_update_study_plan(db, &plan_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing plan id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    srv.router.add("DELETE", "/api/study-plans/:id", ||(req) => {
        var db = request_db()
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var plan_id = segments.at_ref(2).to_string()
            return underlayer_web::handle_delete_study_plan(db, &plan_id, &req)
        } else {
            var body = std::string("{\"error\":\"missing plan id\"}")
            return underlayer_web::send_json_status(400u, &body)
        }
    })
    // ---- Start server ----
    var listen_msg = std::string("[underlayer] Server running at http://localhost:")
    listen_msg.append_string(&underlayer_core::u32_to_string(port))
    underlayer_core::log_line(&listen_msg)
    var courses_msg = std::string("[underlayer] Courses dir: ")
    courses_msg.append_string(&cfg.courses_dir)
    underlayer_core::log_line(&courses_msg)
    srv.serve()

    underlayer_db::close(&raw db)
    return 0
}
