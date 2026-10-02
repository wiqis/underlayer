// underlayer_web — Module root.
// Just the WebConfig struct. Handlers live in separate files:
//   helpers.ch               — send_page, send_json_str, send_error, sv_to_string, render_concept
//   json_helpers.ch          — json_get, json_str, json_get_str, json_int, json_get_int
//   handlers_home.ch         — handle_health, handle_home
//   home_assets.ch           — render_home_css, render_home_js (dynamic course grid loader)
//   handlers_courses.ch      — handle_list_courses, handle_get_course
//   handlers_lessons.ch      — handle_lesson, handle_course_landing
//   handlers_review.ch       — handle_review_start, submit, end, due (5.1.1-5.1.5 modes)
//   handlers_exercises.ch    — handle_get_exercises, submit, hint (4.1.1-4.1.5, 4.2.1-4.2.5)
//   exercise_grade.ch        — grade_exercise for all 8 lesson UI types (4.1.29)
//   handlers_exercises_bulk.ch — handle_exercise_import, handle_exercise_seed, handle_exercise_stats
//   handlers_progress.ch     — handle_progress, handle_course_progress
//   handlers_analytics.ch    — handle_course_analytics, handle_difficulty_analytics, handle_error_analytics, handle_engagement_analytics, handle_velocity_analytics
//   pages_analytics.ch       — render_analytics_page, render_course_analytics_page
//   handlers_analytics_pages.ch — handle_analytics_page, handle_course_analytics_page, handle_analytics_overview_api
//   handlers_learners.ch     — handle_create_learner, handle_get_learner
//   handlers_profiles.ch     — handle_get_profile, handle_update_profile, handle_get_public_profile
//   handlers_settings_api.ch — handle_get_settings, handle_update_settings, handle_get_learning_preferences, handle_update_learning_preferences
//   handlers_settings.ch     — handle_fsrs_optimize/reset/export/import, settings, profile, auth, data
//   pages_auth.ch            — handle_login_page, handle_register_page, handle_forgot_password_page, handle_reset_password_page
//   pages_settings.ch        — render_settings_page, render_profile_page
//   pages_onboarding.ch      — handle_onboarding_page, handle_onboarding_complete, handle_check_onboarding
//   handlers_knowledge_health.ch — handle_knowledge_health, handle_knowledge_health_per_module, handle_knowledge_projection, handle_enroll_course, handle_get_enrollments
//   handlers_learning_path.ch — handle_get_prerequisites, handle_add_prerequisite, handle_remove_prerequisite, handle_can_enroll, handle_skill_assessment, handle_get_assessment
//   handlers_feedback.ch      — handle_submit_feedback, handle_get_concept_feedback (OWNER-SCOPED), handle_report_exercise, handle_feedback_stats
//   handlers_feedback_admin.ch — handle_get_admin_feedback, handle_get_admin_reports, handle_update_feedback_status — all three REFUSED 403, see the file header
//   handlers_bookmarks.ch    — handle_add_bookmark, handle_remove_bookmark, handle_get_bookmarks, handle_check_bookmark
//   handlers_certificates.ch — handle_issue_certificate (gated by completion_gate.ch), handle_get_certificate, handle_get_certificates, handle_certificate_page
//   completion_gate.ch        — require_course_complete: "finished" is the coverage number from learning/src/coverage.ch, >= 100, and nothing else
//   handlers_notes.ch        — handle_create_note, handle_update_note, handle_delete_note, handle_get_concept_notes, handle_search_notes
//   handlers_achievements.ch — handle_get_achievements, handle_check_achievements, handle_achievement_count
//   handlers_course_reviews.ch — handle_submit_review, handle_get_course_reviews, handle_update_review, handle_delete_review, handle_mark_review_helpful, handle_course_rating_summary
//   handlers_streaks.ch      — handle_get_streak, handle_record_activity, handle_weekly_activity
//   handlers_study_plan.ch   — handle_create_study_plan, handle_get_study_plans, handle_update_study_plan, handle_delete_study_plan
//   pages_help.ch            — render_help_page, render_shortcuts_page, render_faq_page, render_about_page
//   static.ch                — content_type_for_ext, file_extension, handle_static_file
//
// Collection-level pages (the course index, the learning path, concept search):
//   routes_data.ch           — RouteStep, PathRoute, mk_step, build_routes, route_orphans
//   routes_formats.ch        — Route 1: the seven container formats
//   routes_link.ch           — Route 2: object files -> linking -> loading -> the neutral core
//   routes_arch.ch           — Route 3: x86-64, AArch64, RISC-V, then the compiler backend
//   routes_verify.ch         — verify_route_order: walks the routes against the real manifests
//   courses_index_data.ch    — ConceptLink, Placement, CatalogCard, module_title_for
//   courses_catalog_build.ch — build_card, build_catalog, resolve_route_course, minutes_of
//   courses_index_render.ch  — #html components for one course card and its concept list
//   courses_path_render.ch   — #html components for a route, a step, its prerequisites, the check
//   courses_orphans.ch       — the courses no route claims, printed rather than omitted
//   pages_courses.ch         — render_courses_page            (GET /courses)
//   pages_path.ch            — render_learning_path_page_index (GET /learning-path)
//   pages_search.ch          — render_search_page             (GET /search)
//   courses_index_assets.ch  — CSS + JS for /courses and /learning-path
//   search_assets.ch         — CSS for /search
//   pages_gate.ch            — render_onboarding_gate: the banner that tells a
//                              signed-in learner with incomplete onboarding
//                              that there is a step left.  GET
//                              /api/onboarding/check shipped and was called
//                              from nowhere; this is its consumer, and it
//                              ships HIDDEN so a signed-out or offline page is
//                              correct before any script runs.
//   lesson_pager.ch          — apply_lesson_pager: prev/next lesson links,
//                              resolved from the manifest the handler already
//                              loaded.  They were filled in by the page's own
//                              fetch, which meant a statically pre-rendered
//                              lesson page had no links at all and its swipe
//                              gesture reloaded the page it was already on.
//   session_js.ch            — render_session_js: THE shared client session
//                              helper (__ulToken / __ulHeaders / __ulFetch /
//                              __ulCourseId / __ulGate).  Seventeen pages each
//                              read localStorage and build a bearer header on
//                              their own, and eleven of them did it without a
//                              try/catch, so blocking site data threw on eleven
//                              pages and not on three.  One helper, one 401
//                              policy, one answer to "which course is this
//                              page about".
//                            — render_auth_destination_js: __ulNextPath and
//                              __ulAfterAuth, which decide where a learner
//                              lands after login or register.  `next` first,
//                              then the onboarding gate, then home.  Both auth
//                              pages used to hardcode '/'.
//   nav_bar.ch               — render_nav_bar, which delegates to the ONE nav in
//                              content/src/lesson_nav.ch.  The nav lives below
//                              web because the 398 lesson pages — the ones that
//                              had none — are built in content/ and cannot
//                              import this layer.
//   search_core.ch           — SearchHit, find_bytes, hit_score, snippet helpers
//   search_scan.ch           — snippet_of, title_less, sort_hits, swap_hits
//   search_walk.ch           — search_concepts: the walk every search goes through
//   handlers_collection_pages.ch — handle_courses_page, handle_learning_path_index, handle_search_page
//   handlers_search_concepts.ch   — handle_search_concepts (GET /api/search/concepts)
//   home_search.ch           — the home page's Ctrl+K modal, now fetching the real index
using std::string

public namespace underlayer_web {

    public struct WebConfig {
        var db : *underlayer_db::DbClient
        var courses_dir : string
    }

}
