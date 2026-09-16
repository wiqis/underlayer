// underlayer_repository — Module root.
// All code lives in separate files:
//   helpers.ch        — parse_i64, parse_int, JSON helpers (public)
//   schema.ch         — init_schema
//   courses.ch        — load_course, list_courses
//   learners.ch       — create_learner, get_learner
//   concept_states.ch — get_concept_state, upsert_concept_state, get_all_concept_states
//   review_items.ch   — get_due_review_items, get_all_review_items, update_review_item, insert_review_item
//   sessions.ch       — create_session, insert_session, finish_session, pause/resume/abort/undo/skip
//   session_items.ch  — record_session_item, get_session_items, get_session_stats, get_learner_sessions
//   exercises.ch      — get_exercises_for_concept, get_exercise, insert_exercise, count_exercises
//   goals.ch          — get_learning_goal, set_learning_goal, delete_learning_goal
//   profiles.ch       — get_profile, upsert_profile, is_username_available, get_profile_by_username
//   settings.ch       — get_settings, upsert_settings, get_learning_preferences, upsert_learning_preferences
//   enrollments.ch    — enroll_learner, get_enrollment, get_learner_enrollments, update_last_accessed, complete_enrollment
//   feedback.ch       — submit_feedback, get_feedback_for_concept, get_all_pending_feedback, update_feedback_status, report_exercise, get_exercise_reports, get_all_exercise_reports, get_feedback_stats
//   prerequisites.ch  — get_prerequisites, add_prerequisite, remove_prerequisite, check_prerequisites, get_missing_prerequisites, save_assessment_result, get_latest_assessment
//   notifications.ch — create_notification, get_notifications, get_unread_count, mark_read, mark_all_read, delete_notification, delete_old_notifications
