# API Reference — Underlayer

Generated from the actual code (`app/main.ch`, `repository/src/schema.ch`, `web/src/`, `repository/src/`) on **2026-09-14**. When you add or change a route, table, or repository function, update this skill in the same commit.

---

## HTTP Routes (app/main.ch)

All routes are registered in `app/main.ch`. Path params are extracted with `underlayer_core::path_segments()` by **position** (router does not substitute params).

### Pages (HTML)

| Method | Path | Handler | Purpose |
|---|---|---|---|
| GET | `/` | `handle_home` | Landing page with course grid |
| GET | `/dashboard` | `handle_dashboard` | Stats, health score, due items |
| GET | `/review` | `handle_review_page` | Review session UI (6 modes) |
| GET | `/progress` | `handle_progress_page` | Progress + analytics UI |
| GET | `/courses/:courseId` | `handle_course_landing` | Course overview page |
| GET | `/courses/:courseId/lessons/:conceptId` | `handle_lesson` | Lesson viewer |
| GET | `/courses/*` | `handle_static_file` | Static assets (files with extensions); falls back to course landing |

### Learners

| Method | Path | Handler |
|---|---|---|
| POST | `/api/learners` | `handle_create_learner` — body: `{name, email}` |
| GET | `/api/learners/:learnerId` | `handle_get_learner` |

### Courses & Lessons

| Method | Path | Handler |
|---|---|---|
| GET | `/api/courses` | `handle_list_courses` |
| GET | `/api/courses/all` | `handle_filter_courses` (7.1.7) |
| GET | `/api/courses/:courseId` | `handle_get_course` |
| GET | `/api/courses/:courseId/lessons/:conceptId` | `handle_lesson` (API JSON/HTML) |
| GET | `/api/search` | `handle_search` (7.1.6) |
| GET | `/api/navigation/:courseId/:conceptId` | `handle_navigation` — prev/next (7.1.2/3/5) |

### Review

| Method | Path | Handler |
|---|---|---|
| GET | `/api/review/start` | `handle_review_start` — `?course_id=&mode=&count=` (5.1.1–5.1.5 modes) |
| POST | `/api/review/submit` | `handle_review_submit` — body: `{concept_id, rating (1–4), course_id, time_spent}` |
| POST | `/api/review/end` | `handle_review_end` |
| GET | `/api/review/due` | `handle_review_due` — `?course_id=&limit=` |
| GET | `/api/review/recommendations` | `handle_session_recommendations` (1.2.25) |
| GET | `/api/review/time-recommendation` | `handle_session_time_recommendation` (1.2.27) |

### Sessions

| Method | Path | Handler |
|---|---|---|
| GET | `/api/sessions` | `handle_session_history` (1.2.21) |
| GET | `/api/sessions/:sessionId` | `handle_session_detail` (1.2.22) |
| GET | `/api/session/detail` | `handle_session_detail` (alias, query param) |
| POST | `/api/session/pause` | `handle_session_pause` (1.2.9) |
| POST | `/api/session/resume` | `handle_session_resume` (1.2.10) |
| POST | `/api/session/abort` | `handle_session_abort` (1.2.11) |
| POST | `/api/session/undo` | `handle_session_undo` (1.2.12) |
| POST | `/api/session/skip` | `handle_session_skip` (1.2.13) |
| GET | `/api/recent` | `handle_recent_history` (7.1.9) |

### Exercises

| Method | Path | Handler |
|---|---|---|
| GET | `/api/exercises/:conceptId` | `handle_get_exercises` |
| POST | `/api/exercises/submit` | `handle_exercise_submit` |
| GET | `/api/exercises/hint` | `handle_exercise_hint` (4.2.x progressive hints) |

### Progress & Analytics

| Method | Path | Handler |
|---|---|---|
| GET | `/api/progress` | `handle_progress` |
| GET | `/api/progress/:courseId` | `handle_course_progress` |
| GET | `/api/progress/export` | `handle_progress_export` (6.1.7) |
| GET | `/api/analytics/sessions` | `handle_session_analytics` (6.2.1) |
| GET | `/api/analytics/concept/:conceptId` | `handle_concept_analytics` (6.2.2) |
| GET | `/api/fsrs/export` | `handle_fsrs_export` |
| POST | `/api/fsrs/import` | `handle_fsrs_import` |

### Weakness

| Method | Path | Handler |
|---|---|---|
| GET | `/api/weaknesses` | `handle_weakness_dashboard` (1.4.21) |
| GET | `/api/weaknesses/export` | `handle_weakness_export` (1.4.23) |
| GET | `/api/weaknesses/compare` | `handle_weakness_compare` (1.4.22) |
| GET | `/api/weaknesses/alerts` | `handle_weakness_alerts` (1.4.24) |

### Goals & Settings

| Method | Path | Handler |
|---|---|---|
| POST | `/api/goals` | `handle_set_goal` (6.1.5) — `{learner_id, course_id, target_date}` |
| DELETE | `/api/goals` | `handle_delete_goal` — query params |
| POST | `/api/fsrs/optimize` | `handle_fsrs_optimize` (1.1.24) |
| POST | `/api/fsrs/reset` | `handle_fsrs_reset` (1.1.25) |

### Health

| Method | Path | Handler |
|---|---|---|
| GET | `/api/health` | `handle_health` — returns `{"status": "ok", "version": "0.1.0"}` |

### Response & error conventions

- Success: JSON built by hand with string appends, sent via `send_json_str(res, &raw body)`
- Errors: `send_error(res, status_u32, &raw msg_string)` → `{"error":"<msg>"}`
- Route lambdas validate segment counts and reply `400` with minimal inline JSON on mismatch
- Note: this diverges from the aspirational `{ok, error:{code,message}}` envelope in `engineering_patterns` — the implemented format is flat `{"error": "..."}`. Follow the implemented format until the envelope is adopted everywhere.

---

## Database Schema (repository/src/schema.ch)

All tables use `CREATE TABLE IF NOT EXISTS` + `ALTER TABLE ... ADD COLUMN` migrations for later-added columns. Schema init is skipped for remote (Turso) DBs.

| Table | Columns | Notes |
|---|---|---|
| `learners` | `id TEXT PK, name TEXT, email TEXT UNIQUE, created_at INTEGER` | |
| `concept_states` | `learner_id, concept_id, course_id, status TEXT DEFAULT 'not_started', attempts INT, correct INT, streak INT, last_studied INT, next_review INT, difficulty_rating REAL, PK(learner_id, concept_id, course_id)` | |
| `review_items` | `id TEXT PK, learner_id, concept_id, course_id, type, front, back, difficulty REAL 5.0, stability REAL 1.0, retrievability REAL 1.0, next_review INT, last_review INT, reps INT, lapses INT, ease_factor REAL 2.5` | `ease_factor` via ALTER migration (1.1.15) |
| `sessions` | `id TEXT PK, learner_id, start_time INT, end_time INT, type, exercises_attempted INT, exercises_correct INT, status TEXT DEFAULT 'active'` | status: active/paused/finished/aborted |
| `session_items` | `id INTEGER PK AUTOINCREMENT, session_id, concept_id, rating INT, time_spent_ms INT, reviewed_at INT` | |
| `exercises` | `id TEXT PK, concept_id, type, question, answer, options_json, correct_index INT, explanation, hint1, hint2, hint3, difficulty REAL 0.5` | |
| `exercises.correct_indices_json` | `TEXT DEFAULT '[]'` (ALTER, 4.1.3) | multi-select support |
| `learning_goals` | `id TEXT PK, learner_id, course_id, target_date INT, created_at INT` | 6.1.5 |

**Indexes:** `idx_cs_learner(concept_states.learner_id)`, `idx_ri_learner(review_items.learner_id)`, `idx_ri_due(review_items.next_review)`, `idx_sess_learner(sessions.learner_id)`, `idx_si_session(session_items.session_id)`, `idx_lg_learner(learning_goals.learner_id)`.

**Ratings (learning/src/main.ch):** Again=1, Hard=2, Good=3, Easy=4.

---

## Database Client API (database/src/main.ch)

```chemical
var db = underlayer_db::make_client(url.copy(), token.copy())  // SQLite path or Turso URL
underlayer_db::is_remote_url(&raw url) : bool                  // true → skip init_schema
underlayer_db::exec_sql(db, &raw sql_string) : ExecResult      // INSERT/UPDATE/CREATE
underlayer_db::query_sql(db, &raw sql_string) : QueryResult    // rows: vector<vector<string>>
underlayer_db::query_sql_single(db, &raw sql_string) : vector<string>
underlayer_db::close(&raw db)
```

Rows are `vector<string>` — convert numeric columns with `parse_i64` / `parse_int` / `parse_f64` from `repository/src/helpers.ch`.

## Repository API (repository/src/)

ALL SQL lives here. Web handlers call these — never write SQL in `web/`.

| File | Functions |
|---|---|
| `schema.ch` | `init_schema(db)` |
| `courses.ch` | `load_course(courses_dir, course_id) : Course`, `list_courses(courses_dir) : vector<Course>` — disk manifest first, hardcoded ELF fallback second |
| `learners.ch` | `create_learner(db, id, name, email)`, `get_learner(db, id) : Learner` |
| `concept_states.ch` | `get_concept_state(db, learner, concept, course) : ConceptState`, `upsert_concept_state(db, *ConceptState)`, `get_all_concept_states(db, learner, course) : vector<ConceptState>` |
| `review_items.ch` | `get_due_review_items(db, learner, course, limit)`, `get_all_review_items(...)`, `update_review_item(db, *ReviewItem)`, `insert_review_item(db, *ReviewItem)` |
| `sessions.ch` | `create_session`, `insert_session`, `finish_session`, `pause_session`, `resume_session`, `abort_session`, `undo_last_item : bool`, `skip_item` |
| `session_items.ch` | `record_session_item(db, session, concept, rating, ms)`, `get_session_items`, `get_session_stats : SessionStats`, `get_learner_sessions(db, learner, limit)`, `get_all_review_history(db, learner)` |
| `exercises.ch` | `get_exercises_for_concept(db, concept, limit)`, `get_exercise(db, id)`, `insert_exercise`, `count_exercises(db, concept) : int` |
| `goals.ch` | `get_learning_goal : GoalResult`, `set_learning_goal`, `delete_learning_goal` |
| `helpers.ch` | `parse_i64`, `parse_int`, `parse_f64`, `json_str`, `json_i64`, `json_int`, `json_get`, `json_get_str`, `json_get_int` (public — shared across repo files) |

## Learning Engine API (learning/src/) — pure functions, no SQL

| File | Functions |
|---|---|
| `fsrs.ch` | `init_fsrs_params`, `fsrs_retrievability(state, elapsed_days)`, `fsrs_next_interval(params, state, rating) : i64`, `fsrs_update_state(params, state, rating) : ReviewState`, `grad_step_interval`, `compute_prediction_error`, `optimize_fsrs_params`, `reset_fsrs_params`, `export_fsrs_params : string`, `log_param_change : string` |
| `session.ch` | `start_review_session(items) : ReviewSession`, `get_current_item(session, out)`, `advance_session`, `is_session_complete : bool` |
| `queue.ch` | `build_review_queue(...)`, `interleave_items(items, strength)`, `compute_adaptive_strength(base, accuracy, streak) : int`, `should_interleave_prereqs`, `get_next_review_items(queue)` |
| `weakness.ch` | `detect_weaknesses(states) : vector<WeaknessReport>`, `suggest_repair`, `compute_weakness_trend`, `detect_weakness_chains`, `cluster_weaknesses`, `predict_weakness : f64`, `should_schedule_repair`, `track_weakness_resolution` |
| `health.ch` | `compute_knowledge_health`, `compute_module_health`, `compute_depth_score`, `compute_breadth_score`, `compute_health_goal`, `check_milestones`, `compute_retention_projection`, `identify_knowledge_gaps`, `compute_health_trend`, `compute_health_comparison`, `identify_knowledge_overlap`, `export_health_json : string` |

## Adding a New Endpoint (checklist)

1. Write handler in `web/src/handlers_<area>.ch` (split file if >250 lines)
2. If new SQL is needed: add function to the right `repository/src/<entity>.ch` — never in `web/`
3. Register route in `app/main.ch` with capture `(|&db|` / `(|&db, &courses_dir|`
4. Extract path params by position via `underlayer_core::path_segments()`
5. Add tests in `tests/src/` (unique port, happy + error path) — see `testing` skill
6. Update this skill's route table and `docs/features-complete.md` (check the item off)
7. Verify: `./scripts/test.sh`, then `./scripts/serve.sh` + `curl localhost:9000/api/health`
