// underlayer_web — Module root.
// Just the WebConfig struct. Handlers live in separate files:
//   helpers.ch               — send_page, send_json_str, send_error, sv_to_string, render_concept
//   json_helpers.ch          — json_get, json_str, json_get_str, json_int, json_get_int
//   handlers_home.ch         — handle_health, handle_home
//   handlers_courses.ch      — handle_list_courses, handle_get_course
//   handlers_lessons.ch      — handle_lesson, handle_course_landing
//   handlers_review.ch       — handle_review_start, submit, end, due (5.1.1-5.1.5 modes)
//   handlers_exercises.ch    — handle_get_exercises, submit, hint (4.1.1-4.1.5, 4.2.1-4.2.5)
//   handlers_exercises_bulk.ch — handle_exercise_import, handle_exercise_seed, handle_exercise_stats
//   handlers_progress.ch     — handle_progress, handle_course_progress
//   handlers_analytics.ch    — handle_course_analytics, handle_difficulty_analytics, handle_error_analytics, handle_engagement_analytics, handle_velocity_analytics
//   handlers_learners.ch     — handle_create_learner, handle_get_learner
//   handlers_profiles.ch     — handle_get_profile, handle_update_profile, handle_get_public_profile
//   handlers_settings_api.ch — handle_get_settings, handle_update_settings, handle_get_learning_preferences, handle_update_learning_preferences
//   handlers_settings.ch     — handle_fsrs_optimize/reset/export/import, settings, profile, auth, data
//   pages_auth.ch            — handle_login_page, handle_register_page, handle_forgot_password_page, handle_reset_password_page
//   pages_settings.ch        — render_settings_page, render_profile_page
//   pages_onboarding.ch      — handle_onboarding_page, handle_onboarding_complete, handle_check_onboarding
//   handlers_knowledge_health.ch — handle_knowledge_health, handle_knowledge_health_per_module, handle_knowledge_projection, handle_enroll_course, handle_get_enrollments
//   handlers_learning_path.ch — handle_get_prerequisites, handle_add_prerequisite, handle_remove_prerequisite, handle_can_enroll, handle_skill_assessment, handle_get_assessment
//   handlers_feedback.ch      — handle_submit_feedback, handle_get_concept_feedback, handle_get_admin_feedback, handle_update_feedback_status, handle_report_exercise, handle_get_admin_reports, handle_feedback_stats
//   static.ch                — content_type_for_ext, file_extension, handle_static_file
using std::string

public namespace underlayer_web {

    public struct WebConfig {
        var db : *underlayer_db::DbClient
        var courses_dir : string
    }

}
