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
