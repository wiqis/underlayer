// Underlayer — Server entrypoint
// Phase 1: Minimal working platform serving static courses.
using std::string
using std::string_view

public func main() : int {
    // ---- Config & DB ----
    var cfg = underlayer_core::load_config()
    var port = cfg.port
    var db_url = cfg.db_url.copy()
    var db_token = cfg.db_token.copy()

    printf("[underlayer] Starting Underlayer on port %s\n", underlayer_core::u32_to_string(port).data())

    var db = underlayer_db::make_client(db_url.copy(), db_token.copy())

    // ---- Init schema (skip for remote DB) ----
    if(!underlayer_db::is_remote_url(&raw db_url)) {
        underlayer_repository::init_schema(&raw db)
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

    // Health check
    srv.router.add("GET", "/api/health", (req, res) => {
        underlayer_web::handle_health(&req, &raw mut res)
    })

    // Dashboard page (7.2.4, 7.2.5, 1.5.20)
    srv.router.add("GET", "/dashboard", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_dashboard(db, courses_dir, &req, &raw mut res)
    }))

    // Course listing
    srv.router.add("GET", "/api/courses", (|&courses_dir|(req, res) => {
        underlayer_web::handle_list_courses(courses_dir, &req, &raw mut res)
    }))

    // Course detail
    srv.router.add("GET", "/api/courses/:courseId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2)
            underlayer_web::handle_get_course(courses_dir, course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var ct = std::string_view("application/json")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("{\"error\": \"missing course id\"}")
            var bv = body.to_view()
            res.write_view(&bv)
        }
    }))

    // Lesson viewer via API
    srv.router.add("GET", "/api/courses/:courseId/lessons/:conceptId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.get_ptr(1)
            var concept_id = segments.get_ptr(3)
            underlayer_web::handle_lesson(courses_dir, course_id, concept_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var ct = std::string_view("application/json")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("{\"error\": \"missing course or concept id\"}")
            var bv = body.to_view()
            res.write_view(&bv)
        }
    }))

    // ---- Review API ----
    srv.router.add("GET", "/api/review/start", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_start(db, courses_dir, &req, &raw mut res)
    }))

    srv.router.add("POST", "/api/review/submit", (|&db|(req, res) => {
        underlayer_web::handle_review_submit(db, &raw mut req, &raw mut res)
    }))

    srv.router.add("POST", "/api/review/end", (|&db|(req, res) => {
        underlayer_web::handle_review_end(db, &raw mut req, &raw mut res)
    }))

    // ---- Due Items ----
    srv.router.add("GET", "/api/review/due", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_due(db, courses_dir, &req, &raw mut res)
    }))

    // ---- Session Recommendations (1.2.25) ----
    srv.router.add("GET", "/api/review/recommendations", (|&db|(req, res) => {
        underlayer_web::handle_session_recommendations(db, &req, &raw mut res)
    }))

    // ---- Progress API ----
    srv.router.add("GET", "/api/progress", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_progress(db, courses_dir, &req, &raw mut res)
    }))

    // ---- Course Progress API ----
    srv.router.add("GET", "/api/progress/:courseId", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_course_progress(db, courses_dir, &req, &raw mut res)
    }))

    // ---- Learning Goals (6.1.5) ----
    srv.router.add("POST", "/api/goals", (|&db|(req, res) => {
        underlayer_web::handle_set_goal(db, &raw mut req, &raw mut res)
    }))
    srv.router.add("DELETE", "/api/goals", (|&db|(req, res) => {
        underlayer_web::handle_delete_goal(db, &req, &raw mut res)
    }))

    // ---- Weakness Dashboard (1.4.21) ----
    srv.router.add("GET", "/api/weaknesses", (|&db|(req, res) => {
        underlayer_web::handle_weakness_dashboard(db, &req, &raw mut res)
    }))

    // ---- Weakness Export (1.4.23) ----
    srv.router.add("GET", "/api/weaknesses/export", (|&db|(req, res) => {
        underlayer_web::handle_weakness_export(db, &req, &raw mut res)
    }))

    // ---- Navigation API (7.1.2, 7.1.3, 7.1.5) ----
    srv.router.add("GET", "/api/navigation/:courseId/:conceptId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.get_ptr(2)
            var concept_id = segments.get_ptr(3)
            underlayer_web::handle_navigation(courses_dir, course_id, concept_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var ct = std::string_view("application/json")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("{\"error\": \"missing course or concept id\"}")
            var bv = body.to_view()
            res.write_view(&bv)
        }
    }))

    // ---- FSRS Settings (1.1.24-1.1.28) ----
    srv.router.add("POST", "/api/fsrs/optimize", (|&db|(req, res) => {
        underlayer_web::handle_fsrs_optimize(db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/fsrs/reset", (|&db|(req, res) => {
        underlayer_web::handle_fsrs_reset(db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/fsrs/export", (|&db|(req, res) => {
        underlayer_web::handle_fsrs_export(db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/fsrs/import", (|&db|(req, res) => {
        underlayer_web::handle_fsrs_import(db, &raw mut req, &raw mut res)
    }))

    // ---- Session History (1.2.21, 1.2.22) ----
    srv.router.add("GET", "/api/sessions", (|&db|(req, res) => {
        underlayer_web::handle_session_history(db, &req, &raw mut res)
    }))

    // ---- Session Detail (1.2.22) ----
    srv.router.add("GET", "/api/sessions/:sessionId", (|&db|(req, res) => {
        underlayer_web::handle_session_detail(db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/session/detail", (|&db|(req, res) => {
        underlayer_web::handle_session_detail(db, &req, &raw mut res)
    }))

    // ---- Session Management (1.2.9-1.2.13) ----
    srv.router.add("POST", "/api/session/pause", (|&db|(req, res) => {
        underlayer_web::handle_session_pause(db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/session/resume", (|&db|(req, res) => {
        underlayer_web::handle_session_resume(db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/session/abort", (|&db|(req, res) => {
        underlayer_web::handle_session_abort(db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/session/undo", (|&db|(req, res) => {
        underlayer_web::handle_session_undo(db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/session/skip", (|&db|(req, res) => {
        underlayer_web::handle_session_skip(db, &req, &raw mut res)
    }))

    // ---- Exercise API (4.1.1-4.1.5, 4.2.1-4.2.5) ----
    srv.router.add("GET", "/api/exercises/:conceptId", (|&db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var concept_id = segments.get_ptr(2)
            underlayer_web::handle_get_exercises(db, concept_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var ct = std::string_view("application/json")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("{\"error\": \"missing concept id\"}")
            var bv = body.to_view()
            res.write_view(&bv)
        }
    }))

    srv.router.add("POST", "/api/exercises/submit", (|&db|(req, res) => {
        underlayer_web::handle_exercise_submit(db, &raw mut req, &raw mut res)
    }))

    srv.router.add("GET", "/api/exercises/hint", (|&db|(req, res) => {
        underlayer_web::handle_exercise_hint(db, &req, &raw mut res)
    }))

    // Course landing page
    srv.router.add("GET", "/courses/:courseId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            var course_id = segments.get_ptr(1)
            underlayer_web::handle_course_landing(courses_dir, course_id, &req, &raw mut res)
        } else {
            underlayer_web::handle_home(&req, &raw mut res)
        }
    }))

    // Lesson viewer via URL path
    srv.router.add("GET", "/courses/:courseId/lessons/:conceptId", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.get_ptr(1)
            var concept_id = segments.get_ptr(3)
            underlayer_web::handle_lesson(courses_dir, course_id, concept_id, &req, &raw mut res)
        } else {
            res.status = 404u
            var ct = std::string_view("text/plain")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("Not found")
            var bv = body.to_view()
            res.write_view(&bv)
        }
    }))

    // Static file serving for course output (HTML, CSS, JS, images)
    srv.router.add("GET", "/courses/*", (|&courses_dir|(req, res) => {
        var path = req.path.to_view()
        // Only serve files, not directory paths (must have an extension)
        var has_ext = false
        var i : size_t = 0
        while(i < path.size()) {
            if(path.get(i) == '.') { has_ext = true }
            i = i + 1
        }
        if(has_ext) {
            underlayer_web::handle_static_file(courses_dir, &raw path, &raw mut res)
        } else {
            // Try course landing page
            var segments = underlayer_core::path_segments(&path)
            if(segments.size() >= 2) {
                var course_id = segments.get_ptr(1)
                underlayer_web::handle_course_landing(courses_dir, course_id, &req, &raw mut res)
            } else {
                underlayer_web::handle_home(&req, &raw mut res)
            }
        }
    }))

    // Home page
    srv.router.add("GET", "/", (req, res) => {
        underlayer_web::handle_home(&req, &raw mut res)
    })

    // ---- Start server ----
    printf("[underlayer] Server running at http://localhost:%s\n", underlayer_core::u32_to_string(port).data())
    printf("[underlayer] Courses dir: %s\n", cfg.courses_dir.data())
    srv.serve()

    underlayer_db::close(&raw db)
    return 0
}
