// underlayer_web — Module root.
// Just the WebConfig struct. Handlers live in separate files:
//   helpers.ch            — send_page, send_json_str, send_error, sv_to_string, render_concept
//   json_helpers.ch       — json_get, json_str, json_get_str, json_int, json_get_int
//   handlers_home.ch      — handle_health, handle_home
//   handlers_courses.ch   — handle_list_courses, handle_get_course
//   handlers_lessons.ch   — handle_lesson, handle_course_landing
//   handlers_review.ch    — handle_review_start, submit, end, due (5.1.1-5.1.5 modes)
//   handlers_exercises.ch — handle_get_exercises, submit, hint (4.1.1-4.1.5, 4.2.1-4.2.5)
//   handlers_progress.ch  — handle_progress, handle_course_progress
//   handlers_learners.ch  — handle_create_learner, handle_get_learner
//   static.ch             — content_type_for_ext, file_extension, handle_static_file
using std::string

public namespace underlayer_web {

    public struct WebConfig {
        var db : *underlayer_db::DbClient
        var courses_dir : string
    }

}
