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

    // ---- Learner CRUD ----
    srv.router.add("POST", "/api/learners", (|db|(req, res) => {
        underlayer_web::handle_create_learner(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/learners/:learnerId", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var learner_id = segments.get_ptr(2)
            underlayer_web::handle_get_learner(&raw db, learner_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var ct = std::string_view("application/json")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("{\"error\": \"missing learner id\"}")
            var bv = body.to_view()
            res.write_view(&bv)
        }
    }))

    // ---- Health check ----
    srv.router.add("GET", "/api/health", (req, res) => {
        underlayer_web::handle_health(&req, &raw mut res)
    })

    // Review page (HTML UI)
    srv.router.add("GET", "/review", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_page(db, courses_dir, &req, &raw mut res)
    }))

    // Progress page (HTML UI)
    srv.router.add("GET", "/progress", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_progress_page(db, courses_dir, &req, &raw mut res)
    }))

    // Dashboard page (7.2.4, 7.2.5, 1.5.20)
    srv.router.add("GET", "/dashboard", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_dashboard(db, courses_dir, &req, &raw mut res)
    }))

    // Course listing
    srv.router.add("GET", "/api/courses", (|&courses_dir|(req, res) => {
        underlayer_web::handle_list_courses(courses_dir, &req, &raw mut res)
    }))

    // Filter Courses (7.1.7)
    srv.router.add("GET", "/api/courses/all", (|&courses_dir|(req, res) => {
        underlayer_web::handle_filter_courses(courses_dir, &req, &raw mut res)
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

    // ---- Time-of-Day Recommendation (1.2.27) ----
    srv.router.add("GET", "/api/review/time-recommendation", (|&db|(req, res) => {
        underlayer_web::handle_session_time_recommendation(db, &req, &raw mut res)
    }))

    // ---- Search (7.1.6) ----
    srv.router.add("GET", "/api/search", (|&courses_dir|(req, res) => {
        underlayer_web::handle_search(courses_dir, &req, &raw mut res)
    }))

    // ---- Filter Courses (7.1.7) ----
    srv.router.add("GET", "/api/courses/all", (|&courses_dir|(req, res) => {
        underlayer_web::handle_filter_courses(courses_dir, &req, &raw mut res)
    }))

    // ---- Recent History (7.1.9) ----
    srv.router.add("GET", "/api/recent", (|&db|(req, res) => {
        underlayer_web::handle_recent_history(db, &req, &raw mut res)
    }))

    // ---- Progress API ----
    srv.router.add("GET", "/api/progress", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_progress(db, courses_dir, &req, &raw mut res)
    }))

    // ---- Progress Export (6.1.7) ----
    srv.router.add("GET", "/api/progress/export", (|&db|(req, res) => {
        underlayer_web::handle_progress_export(db, &req, &raw mut res)
    }))

    // ---- Session Analytics (6.2.1) ----
    srv.router.add("GET", "/api/analytics/sessions", (|&db|(req, res) => {
        underlayer_web::handle_session_analytics(db, &req, &raw mut res)
    }))

    // ---- Concept Analytics (6.2.2) ----
    srv.router.add("GET", "/api/analytics/concept/:conceptId", (|&db, &courses_dir|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.get_ptr(3)
            var course_id = string("elf")
            underlayer_web::handle_concept_analytics(db, concept_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var ct = std::string_view("application/json")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("{\"error\": \"missing concept id\"}")
            var bv = body.to_view()
            res.write_view(&bv)
        }
    }))

    // ---- Course Analytics (6.2.3) ----
    srv.router.add("GET", "/api/analytics/course/:courseId", (|&db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.get_ptr(3)
            underlayer_web::handle_course_analytics(db, course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var ct = std::string_view("application/json")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("{\"error\": \"missing course id\"}")
            var bv = body.to_view()
            res.write_view(&bv)
        }
    }))

    // ---- Difficulty Analytics (6.2.8) ----
    srv.router.add("GET", "/api/analytics/difficulty", (|&db|(req, res) => {
        underlayer_web::handle_difficulty_analytics(db, &req, &raw mut res)
    }))

    // ---- Error Analytics (6.2.9) ----
    srv.router.add("GET", "/api/analytics/errors", (|&db|(req, res) => {
        underlayer_web::handle_error_analytics(db, &req, &raw mut res)
    }))

    // ---- Engagement Analytics (6.2.13) ----
    srv.router.add("GET", "/api/analytics/engagement", (|&db|(req, res) => {
        underlayer_web::handle_engagement_analytics(db, &req, &raw mut res)
    }))

    // ---- Velocity Analytics (6.2.14) ----
    srv.router.add("GET", "/api/analytics/velocity", (|&db|(req, res) => {
        underlayer_web::handle_velocity_analytics(db, &req, &raw mut res)
    }))

    // ---- Learning Analytics (P2 6.2.4-6.2.7, 6.2.10-6.2.12, 6.2.15) ----
    srv.router.add("GET", "/api/analytics/temporal", (|&db|(req, res) => {
        underlayer_web::handle_temporal_analytics(db, &req, &raw mut res)
    }))

    srv.router.add("GET", "/api/analytics/retention", (|&db|(req, res) => {
        underlayer_web::handle_retention_analytics(db, &req, &raw mut res)
    }))

    srv.router.add("GET", "/api/analytics/dropoff", (|&db|(req, res) => {
        underlayer_web::handle_dropoff_analytics(db, &req, &raw mut res)
    }))

    srv.router.add("GET", "/api/analytics/funnel", (|&db|(req, res) => {
        underlayer_web::handle_funnel_analytics(db, &req, &raw mut res)
    }))

    srv.router.add("GET", "/api/analytics/comparative", (|&db|(req, res) => {
        underlayer_web::handle_comparative_analytics(db, &req, &raw mut res)
    }))

    srv.router.add("GET", "/api/analytics/platform", (|&db|(req, res) => {
        underlayer_web::handle_platform_analytics(db, &req, &raw mut res)
    }))

    srv.router.add("GET", "/api/analytics/cohorts", (|&db|(req, res) => {
        underlayer_web::handle_cohort_analytics(db, &req, &raw mut res)
    }))

    srv.router.add("GET", "/api/analytics/devices", (|&db|(req, res) => {
        underlayer_web::handle_device_analytics(db, &req, &raw mut res)
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

    // ---- Weakness Compare (1.4.22) ----
    srv.router.add("GET", "/api/weaknesses/compare", (|&db|(req, res) => {
        underlayer_web::handle_weakness_compare(db, &req, &raw mut res)
    }))

    // ---- Weakness Alerts (1.4.24) ----
    srv.router.add("GET", "/api/weaknesses/alerts", (|&db|(req, res) => {
        underlayer_web::handle_weakness_alerts(db, &req, &raw mut res)
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

    // ---- Nav Status (P2 7.1.13 progress indicator, P2 7.1.15 due indicator) ----
    srv.router.add("GET", "/api/nav-status", (|&db|(req, res) => {
        underlayer_web::handle_nav_status(db, &req, &raw mut res)
    }))

    // ---- Nav Search / Quick Jump (P2 7.1.10 command palette) ----
    srv.router.add("GET", "/api/nav-search", (req, res) => {
        underlayer_web::handle_nav_search(&req, &raw mut res)
    })

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

    // ---- Bulk Exercise Import API ----
    srv.router.add("POST", "/api/exercises/import", (|&db|(req, res) => {
        underlayer_web::handle_exercise_import(db, &raw mut req, &raw mut res)
    }))
    srv.router.add("POST", "/api/exercises/seed", (|&db|(req, res) => {
        underlayer_web::handle_exercise_seed(db, &raw mut req, &raw mut res)
    }))
    srv.router.add("GET", "/api/exercises/stats", (|&db|(req, res) => {
        underlayer_web::handle_exercise_stats(db, &req, &raw mut res)
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

    // ---- Account management routes (Section 16) ----
    // Auth pages
    srv.router.add("GET", "/login", (req, res) => {
        underlayer_web::handle_login_page(&req, &raw mut res)
    })
    srv.router.add("GET", "/register", (req, res) => {
        underlayer_web::handle_register_page(&req, &raw mut res)
    })
    srv.router.add("GET", "/forgot-password", (req, res) => {
        underlayer_web::handle_forgot_password_page(&req, &raw mut res)
    })
    srv.router.add("GET", "/reset-password", (req, res) => {
        underlayer_web::handle_reset_password_page(&req, &raw mut res)
    })
    // Settings page
    srv.router.add("GET", "/settings", (req, res) => {
        underlayer_web::handle_settings_page(&req, &raw mut res)
    })
    srv.router.add("GET", "/components", (req, res) => {
        underlayer_web::handle_components_demo_page(&req, &raw mut res)
    })
    srv.router.add("GET", "/u/:username", (req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            underlayer_web::handle_profile_page(&req, &raw mut res)
        } else {
            res.status = 404u
            var ct = std::string_view("text/plain")
            res.set_header_view(std::string_view("Content-Type"), &ct)
            var body = std::string("Not found")
            var bv = body.to_view()
            res.write_view(&bv)
        }
    })
    // Auth API (from handlers_auth.ch)
    srv.router.add("POST", "/api/auth/register", (|db|(req, res) => {
        underlayer_web::handle_register(&raw db, &raw mut req, &raw mut res)
    }))
    srv.router.add("POST", "/api/auth/login", (|db|(req, res) => {
        underlayer_web::handle_login(&raw db, &raw mut req, &raw mut res)
    }))
    srv.router.add("POST", "/api/auth/logout", (|db|(req, res) => {
        underlayer_web::handle_logout(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/auth/me", (|db|(req, res) => {
        underlayer_web::handle_get_me(&raw db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/auth/forgot-password", (|db|(req, res) => {
        underlayer_web::handle_forgot_password(&raw db, &raw mut req, &raw mut res)
    }))
    srv.router.add("POST", "/api/auth/reset-password", (|db|(req, res) => {
        underlayer_web::handle_reset_password(&raw db, &raw mut req, &raw mut res)
    }))
    srv.router.add("POST", "/api/auth/verify-email", (|db|(req, res) => {
        underlayer_web::handle_verify_email(&raw db, &raw mut req, &raw mut res)
    }))
    srv.router.add("GET", "/api/user/login-history", (|db|(req, res) => {
        underlayer_web::handle_login_history(&raw db, &req, &raw mut res)
    }))
    // Profile API (from handlers_profiles.ch)
    srv.router.add("GET", "/api/user/profile", (|db|(req, res) => {
        underlayer_web::handle_get_profile(&raw db, &req, &raw mut res)
    }))
    srv.router.add("PUT", "/api/user/profile", (|db|(req, res) => {
        underlayer_web::handle_update_profile(&raw db, &req, &raw mut res)
    }))
    // Settings API (from handlers_settings.ch)
    srv.router.add("GET", "/api/user/settings", (|db|(req, res) => {
        underlayer_web::handle_get_settings(&raw db, &req, &raw mut res)
    }))
    srv.router.add("PUT", "/api/user/settings", (|db|(req, res) => {
        underlayer_web::handle_update_settings(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/user/learning-preferences", (|db|(req, res) => {
        underlayer_web::handle_get_learning_preferences(&raw db, &req, &raw mut res)
    }))
    srv.router.add("PUT", "/api/user/learning-preferences", (|db|(req, res) => {
        underlayer_web::handle_update_learning_preferences(&raw db, &req, &raw mut res)
    }))
    // Data management API (from handlers_data.ch)
    srv.router.add("GET", "/api/user/export", (|db|(req, res) => {
        underlayer_web::handle_export_data(&raw db, &req, &raw mut res)
    }))
    srv.router.add("DELETE", "/api/user/data/:type", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var type_sv = segments.get_ptr(3)
            var data_type = type_sv.to_string()
            underlayer_web::handle_delete_data(&raw db, &raw data_type, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing type parameter\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("DELETE", "/api/user/account", (|db|(req, res) => {
        underlayer_web::handle_delete_account(&raw db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/user/deactivate", (|db|(req, res) => {
        underlayer_web::handle_deactivate_account(&raw db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/user/reactivate", (|db|(req, res) => {
        underlayer_web::handle_reactivate_account(&raw db, &req, &raw mut res)
    }))
    // Progress sharing (from handlers_data.ch)
    srv.router.add("POST", "/api/progress/share", (|db|(req, res) => {
        underlayer_web::handle_share_progress(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/progress/shared/:token", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var token_sv = segments.get_ptr(3)
            underlayer_web::handle_get_shared_progress(&raw db, token_sv, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing token\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("POST", "/api/progress/import", (|db|(req, res) => {
        underlayer_web::handle_import_progress(&raw db, &mut req, &raw mut res)
    }))

    srv.router.add("GET", "/api/user/:username", (|db|(req, res) => {
        underlayer_web::handle_get_public_profile(&raw db, &req, &raw mut res)
    }))

    // ---- Knowledge Health API (1.5.20) ----
    srv.router.add("GET", "/api/health/knowledge", (|db|(req, res) => {
        underlayer_web::handle_knowledge_health(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/health/knowledge/per-module", (|db, &courses_dir|(req, res) => {
        underlayer_web::handle_knowledge_health_per_module(&raw db, courses_dir, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/health/knowledge/projection", (|db|(req, res) => {
        underlayer_web::handle_knowledge_projection(&raw db, &req, &raw mut res)
    }))

    // ---- Course Enrollment API ----
    srv.router.add("POST", "/api/courses/:courseId/enroll", (|db|(req, res) => {
        underlayer_web::handle_enroll_course(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/enrollments", (|db|(req, res) => {
        underlayer_web::handle_get_enrollments(&raw db, &req, &raw mut res)
    }))

    // ---- Onboarding (Agent 1) ----
    srv.router.add("GET", "/onboarding", (req, res) => {
        underlayer_web::handle_onboarding_page(&req, &raw mut res)
    })
    srv.router.add("POST", "/api/onboarding/complete", (|db|(req, res) => {
        underlayer_web::handle_onboarding_complete(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/onboarding/check", (|db|(req, res) => {
        underlayer_web::handle_check_onboarding(&raw db, &req, &raw mut res)
    }))

    // ---- Profile stats & courses (Agent 5) ----
    srv.router.add("GET", "/api/user/:username/stats", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var username = segments.get_ptr(2).to_string()
            underlayer_web::handle_profile_stats(&raw db, &username, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing username\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/api/user/:username/courses", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var username = segments.get_ptr(2).to_string()
            underlayer_web::handle_profile_courses(&raw db, &username, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing username\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))

    // ---- Content Feedback API ----
    srv.router.add("POST", "/api/feedback", (|db|(req, res) => {
        underlayer_web::handle_submit_feedback(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/feedback/stats", (|db|(req, res) => {
        underlayer_web::handle_feedback_stats(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/feedback/admin", (|db|(req, res) => {
        underlayer_web::handle_get_admin_feedback(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/feedback/admin/reports", (|db|(req, res) => {
        underlayer_web::handle_get_admin_reports(&raw db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/feedback/report-exercise", (|db|(req, res) => {
        underlayer_web::handle_report_exercise(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/feedback/concept/:conceptId", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.get_ptr(3).to_string()
            underlayer_web::handle_get_concept_feedback(&raw db, &concept_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing concept id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("PUT", "/api/feedback/:id/status", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var feedback_id = segments.get_ptr(3).to_string()
            underlayer_web::handle_update_feedback_status(&raw db, &feedback_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing feedback id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))

    // ---- Notifications API ----
    srv.router.add("GET", "/api/notifications", (|db|(req, res) => {
        underlayer_web::handle_get_notifications(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/notifications/unread-count", (|db|(req, res) => {
        underlayer_web::handle_unread_count(&raw db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/notifications/read-all", (|db|(req, res) => {
        underlayer_web::handle_mark_all_read(&raw db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/notifications/:id/read", (|db|(req, res) => {
        underlayer_web::handle_mark_read(&raw db, &req, &raw mut res)
    }))
    srv.router.add("DELETE", "/api/notifications/:id", (|db|(req, res) => {
        underlayer_web::handle_delete_notification(&raw db, &req, &raw mut res)
    }))

    // ---- Course Prerequisites API ----
    srv.router.add("GET", "/api/courses/:courseId/prerequisites", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_get_prerequisites(&raw db, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("POST", "/api/courses/:courseId/prerequisites", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_add_prerequisite(&raw db, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("DELETE", "/api/courses/:courseId/prerequisites/:requiredId", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var course_id = segments.get_ptr(2).to_string()
            var required_id = segments.get_ptr(3).to_string()
            underlayer_web::handle_remove_prerequisite(&raw db, &course_id, &required_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course or required id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/api/courses/:courseId/can-enroll", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_can_enroll(&raw db, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("POST", "/api/courses/:courseId/assess", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_skill_assessment(&raw db, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/api/courses/:courseId/assessment", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_get_assessment(&raw db, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))

    // ---- Course Reviews API ----
    srv.router.add("POST", "/api/courses/:courseId/reviews", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_submit_review(&raw db, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/api/courses/:courseId/reviews", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_get_course_reviews(&raw db, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/api/courses/:courseId/rating", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_course_rating_summary(&raw db, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("PUT", "/api/reviews/:id", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var review_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_update_review(&raw db, &review_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing review id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("DELETE", "/api/reviews/:id", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var review_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_delete_review(&raw db, &review_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing review id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("POST", "/api/reviews/:id/helpful", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var review_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_mark_review_helpful(&raw db, &review_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing review id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))

    // ---- Bookmarks API ----
    srv.router.add("POST", "/api/bookmarks", (|db|(req, res) => {
        underlayer_web::handle_add_bookmark(&raw db, &req, &raw mut res)
    }))
    srv.router.add("DELETE", "/api/bookmarks/:conceptId", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var concept_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_remove_bookmark(&raw db, &concept_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing concept id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/api/bookmarks", (|db|(req, res) => {
        underlayer_web::handle_get_bookmarks(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/bookmarks/check/:conceptId", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.get_ptr(3).to_string()
            underlayer_web::handle_check_bookmark(&raw db, &concept_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing concept id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))

    // ---- Certificates API ----
    srv.router.add("POST", "/api/certificates", (|db|(req, res) => {
        underlayer_web::handle_issue_certificate(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/certificates", (|db|(req, res) => {
        underlayer_web::handle_get_certificates(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/certificates/:id", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var cert_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_get_certificate(&raw db, &cert_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing certificate id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/certificates/:id", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            var cert_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_certificate_page(&raw db, &cert_id, &req, &raw mut res)
        } else {
            res.status = 400u
            res.write_view(&(std::string("missing certificate id").to_view()))
        }
    }))

    // ---- Analytics Dashboard ----
    srv.router.add("GET", "/analytics", (|db|(req, res) => {
        underlayer_web::handle_analytics_page(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/analytics/overview", (|db|(req, res) => {
        underlayer_web::handle_analytics_overview_api(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/analytics/:courseId", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 2) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_course_analytics_page(&raw db, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            res.write_view(&(std::string("missing course id").to_view()))
        }
    }))

    // ---- Learning Path Visualization ----
    srv.router.add("GET", "/api/courses/:courseId/path", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_learning_path_api(&raw db, &courses_dir, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing course id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/courses/:courseId/path", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var course_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_learning_path_page(&raw db, &courses_dir, &course_id, &req, &raw mut res)
        } else {
            res.status = 400u
            res.write_view(&(std::string("missing course id").to_view()))
        }
    }))

    // ---- Help & Guide Pages ----
    srv.router.add("GET", "/help", (|db|(req, res) => {
        underlayer_web::handle_help_page(&req, &raw mut res)
    }))
    srv.router.add("GET", "/shortcuts", (|db|(req, res) => {
        underlayer_web::handle_shortcuts_page(&req, &raw mut res)
    }))
    srv.router.add("GET", "/faq", (|db|(req, res) => {
        underlayer_web::handle_faq_page(&req, &raw mut res)
    }))
    srv.router.add("GET", "/about", (|db|(req, res) => {
        underlayer_web::handle_about_page(&req, &raw mut res)
    }))

    // ---- Notes API ----
    srv.router.add("POST", "/api/notes", (|db|(req, res) => {
        underlayer_web::handle_create_note(&raw db, &req, &raw mut res)
    }))
    srv.router.add("PUT", "/api/notes/:id", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var note_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_update_note(&raw db, &note_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing note id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("DELETE", "/api/notes/:id", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var note_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_delete_note(&raw db, &note_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing note id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/api/notes/concept/:conceptId", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 4) {
            var concept_id = segments.get_ptr(3).to_string()
            underlayer_web::handle_get_concept_notes(&raw db, &concept_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing concept id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("GET", "/api/notes/search", (|db|(req, res) => {
        underlayer_web::handle_search_notes(&raw db, &req, &raw mut res)
    }))

    // ---- Achievements API ----
    srv.router.add("GET", "/api/achievements", (|db|(req, res) => {
        underlayer_web::handle_get_achievements(&raw db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/achievements/check", (|db|(req, res) => {
        underlayer_web::handle_check_achievements(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/achievements/count", (|db|(req, res) => {
        underlayer_web::handle_achievement_count(&raw db, &req, &raw mut res)
    }))

    // ---- Streaks API ----
    srv.router.add("GET", "/api/streaks", (|db|(req, res) => {
        underlayer_web::handle_get_streak(&raw db, &req, &raw mut res)
    }))
    srv.router.add("POST", "/api/streaks/activity", (|db|(req, res) => {
        underlayer_web::handle_record_activity(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/streaks/weekly", (|db|(req, res) => {
        underlayer_web::handle_weekly_activity(&raw db, &req, &raw mut res)
    }))

    // ---- Study Planner API ----
    srv.router.add("POST", "/api/study-plans", (|db|(req, res) => {
        underlayer_web::handle_create_study_plan(&raw db, &req, &raw mut res)
    }))
    srv.router.add("GET", "/api/study-plans", (|db|(req, res) => {
        underlayer_web::handle_get_study_plans(&raw db, &req, &raw mut res)
    }))
    srv.router.add("PUT", "/api/study-plans/:id", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var plan_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_update_study_plan(&raw db, &plan_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing plan id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))
    srv.router.add("DELETE", "/api/study-plans/:id", (|db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var plan_id = segments.get_ptr(2).to_string()
            underlayer_web::handle_delete_study_plan(&raw db, &plan_id, &req, &raw mut res)
        } else {
            res.status = 400u
            var body = std::string("{\"error\":\"missing plan id\"}")
            var bv = body.to_view()
            res.set_header_view(std::string_view("Content-Type"), &std::string_view("application/json"))
            res.write_view(&bv)
        }
    }))

    // ---- Start server ----
    printf("[underlayer] Server running at http://localhost:%s\n", underlayer_core::u32_to_string(port).data())
    printf("[underlayer] Courses dir: %s\n", cfg.courses_dir.data())
    srv.serve()

    underlayer_db::close(&raw db)
    return 0
}
