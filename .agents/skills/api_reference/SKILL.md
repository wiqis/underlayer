# API Reference — Underlayer

Generated from the actual code (`app/main.ch`, `repository/src/schema.ch`, `web/src/`, `repository/src/`) on **2026-09-17**; routes re-verified **2026-09-24** (no route changes). When you add or change a route, table, or repository function, update this skill in the same commit.

---

## HTTP Routes (app/main.ch)

All routes are registered in `app/main.ch` (~1189 lines, ~175 routes). Path params are extracted with `underlayer_core::path_segments()` by **position** (router does not substitute params).

**Auth convention:** protected endpoints resolve the learner via `Authorization: Bearer <token>` → `underlayer_web::auth_get_learner_id(db, req)` (in `web/src/handlers_auth.ch`), which looks up the SHA-hashed token in the `auth_sessions` table. Unauthenticated calls get a 401-style error. Older endpoints (progress, review, courses) still take `learner_id` explicitly as a query/body param.

### Pages (HTML)

| Method | Path | Handler | Purpose |
|---|---|---|---|
| GET | `/` | `handle_home` | Landing page; course grid is client-rendered from `GET /api/courses` (2.1.25 — CSS/JS in `web/src/home_assets.ch`, not hardcoded) |
| GET | `/dashboard` | `handle_dashboard` | Stats, health score, due items |
| GET | `/review` | `handle_review_page` | Review session UI (6 modes) |
| GET | `/progress` | `handle_progress_page` | Progress + analytics UI |
| GET | `/analytics`, `/analytics/:courseId` | `handle_analytics_page(s)` | Analytics pages |
| GET | `/courses/:courseId` | `handle_course_landing` | Course overview page |
| GET | `/courses/:courseId/lessons/:conceptId` | `handle_lesson` | Lesson viewer |
| GET | `/courses/:courseId/path` | `handle_learning_path_page` | Learning-path visualization |
| GET | `/login`, `/register`, `/forgot-password`, `/reset-password` | `pages_auth.ch` | Auth pages |
| GET | `/settings`, `/components` | `pages_settings.ch`, `pages_components.ch` | Settings UI, components demo |
| GET | `/onboarding` | `handle_onboarding_page` | Onboarding flow |
| GET | `/u/:username` | `pages_profiles.ch` | Public profile page |
| GET | `/help`, `/shortcuts`, `/faq`, `/about` | `pages_help.ch` | Help pages |
| GET | `/terms`, `/privacy` | `pages_legal.ch` | Legal pages |
| GET | `/bookmarks`, `/notes`, `/study-plans`, `/achievements`, `/streaks`, `/notifications`, `/certificates` | matching `pages_*.ch` | Feature pages |
| GET | `/courses/*` | `handle_static_file` | Static assets (files with extensions); falls back to course landing |
| GET | `/certificates/:id` | `handle_certificate_page` | Public certificate page |

### Learners

| Method | Path | Handler |
|---|---|---|
| POST | `/api/learners` | `handle_create_learner` — body: `{name, email}` |
| GET | `/api/learners/:learnerId` | `handle_get_learner` |

### Courses & Lessons

| Method | Path | Handler |
|---|---|---|
| GET | `/api/courses` | `handle_list_courses` — `{id,title,version,modules,concepts,difficulty,importance,description}`; feeds home grid + onboarding |
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

### Auth & Accounts (`handlers_auth.ch`, `handlers_profiles.ch`, `handlers_settings.ch`, `pages_onboarding.ch`)

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/auth/register` | Create account → `{session_token, learner}` |
| POST | `/api/auth/login` | Login → `{session_token, learner}` (30-day session) |
| POST | `/api/auth/logout` | Invalidate session |
| GET | `/api/auth/me` | Current learner from bearer token |
| POST | `/api/auth/forgot-password`, `/api/auth/reset-password` | Password reset (token-based) |
| POST | `/api/auth/verify-email` | Email verification token |
| GET | `/api/user/login-history` | Login history (`login_history` table) |
| GET/PUT | `/api/user/profile` | Profile get/update |
| GET/PUT | `/api/user/settings` | Display settings (theme, font, language) |
| GET/PUT | `/api/user/learning-preferences` | Learning prefs (session length, goals) |
| GET | `/api/user/export` | GDPR-style data export |
| DELETE | `/api/user/data/:type` | Delete one data type |
| DELETE | `/api/user/account` | Delete account + all data |
| POST | `/api/user/deactivate`, `/api/user/reactivate` | Account status |
| GET | `/api/user/:username` (+`/stats`, `/courses`) | Public profile data |
| POST | `/api/onboarding/complete`, GET `/api/onboarding/check` | Onboarding state |

### Enrollments & Learning Paths (`handlers_knowledge_health.ch`, `handlers_learning_path.ch`)

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/courses/:courseId/enroll` | Enroll learner |
| GET | `/api/enrollments` | Learner's enrollments |
| GET/POST/DELETE | `/api/courses/:courseId/prerequisites(/:requiredId)` | Course prerequisite graph |
| GET | `/api/courses/:courseId/can-enroll` | Prerequisite check |
| POST/GET | `/api/courses/:courseId/assess(ment)` | Skill assessment / placement |

### Social & Community (`handlers_course_reviews.ch`, `handlers_feedback.ch`)

| Method | Path | Purpose |
|---|---|---|
| POST/GET | `/api/courses/:courseId/reviews` | Course reviews |
| GET | `/api/courses/:courseId/rating` | Rating summary |
| PUT/DELETE | `/api/reviews/:id` | Edit/delete own review |
| POST | `/api/reviews/:id/helpful` | Mark review helpful |
| POST | `/api/feedback` (+`/stats`, `/admin`, `/admin/reports`, `/report-exercise`, `/concept/:conceptId`) | Content feedback + exercise reports |
| PUT | `/api/feedback/:id/status` | Admin moderation |

### Notifications, Bookmarks, Notes, Streaks, Achievements, Certificates, Study Plans

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/notifications` (+`/unread-count`) | List notifications |
| POST | `/api/notifications/read-all`, `/api/notifications/:id/read` | Mark read |
| DELETE | `/api/notifications/:id` | Delete notification |
| POST/GET | `/api/bookmarks`, DELETE `/api/bookmarks/:conceptId`, GET `/api/bookmarks/check/:conceptId` | Bookmarks |
| GET/POST | `/api/notes`, PUT/DELETE `/api/notes/:id` | Notes CRUD |
| GET | `/api/notes/concept/:conceptId`, `/api/notes/search` | Note lookup |
| POST | `/api/learning/view` | Record learning event |
| GET/POST | `/api/streaks` (+`/weekly`, `/activity`) | Streak data |
| GET/POST | `/api/achievements` (+`/check`, `/count`) | Achievements |
| GET/POST/PUT/DELETE | `/api/study-plans(/:id)` | Study plans |
| POST/GET | `/api/certificates`, GET `/api/certificates/:id` | Certificates |
| GET | `/api/nav-status`, `/api/nav-search` | Navigation status + search |
| GET | `/api/health/knowledge(/per-module)(/projection)` | Knowledge health API |

### Extended Analytics (`handlers_analytics*.ch`, `repository/src/analytics_queries.ch`)

| Method | Path |
|---|---|
| GET | `/api/analytics/overview`, `/sessions`, `/concept/:conceptId`, `/course/:courseId` |
| GET | `/api/analytics/difficulty`, `/errors`, `/engagement`, `/velocity` |
| GET | `/api/analytics/temporal`, `/retention`, `/dropoff`, `/funnel` |
| GET | `/api/analytics/comparative`, `/platform`, `/cohorts`, `/devices` |
| GET/POST | `/api/progress/share`, GET `/api/progress/shared/:token` — shareable progress |
| GET/POST | `/api/progress/export`, `/api/progress/import` |

### Response & error conventions

- Success: JSON built by hand with string appends, sent via `send_json_str(res, &raw body)`
- Errors: `send_error(res, status_u32, &raw msg_string)` → `{"error":"<msg>"}`
- Route lambdas validate segment counts and reply `400` with minimal inline JSON on mismatch
- Note: this diverges from the aspirational `{ok, error:{code,message}}` envelope in `engineering_patterns` — the implemented format is flat `{"error": "..."}`. Follow the implemented format until the envelope is adopted everywhere.

---

## Database Schema (repository/src/schema.ch)

All tables use `CREATE TABLE IF NOT EXISTS` + `ALTER TABLE ... ADD COLUMN` migrations for later-added columns. Schema init is skipped for remote (Turso) DBs. **~35 tables** as of 2026-09-17; highlights below (read `schema.ch` for full column lists).

### Core learning

| Table | Columns (abridged) | Notes |
|---|---|---|
| `learners` | `id TEXT PK, name, email UNIQUE, password_hash, created_at` | `password_hash` added with auth |
| `concept_states` | `learner_id, concept_id, course_id, status, attempts, correct, streak, last_studied, next_review, difficulty_rating, PK(learner_id, concept_id, course_id)` | |
| `review_items` | `id TEXT PK, learner_id, concept_id, course_id, type, front, back, difficulty REAL 5.0, stability REAL 1.0, retrievability REAL 1.0, next_review, last_review, reps, lapses, ease_factor REAL 2.5` | |
| `sessions` | `id TEXT PK, learner_id, start_time, end_time, type, exercises_attempted, exercises_correct, status` | status: active/paused/finished/aborted |
| `session_items` | `id INTEGER PK AUTOINCREMENT, session_id, concept_id, rating, time_spent_ms, reviewed_at` | |
| `exercises` | `id TEXT PK, concept_id, type, question, answer, options_json, correct_index, explanation, hint1-3, difficulty REAL 0.5` + `correct_indices_json` (ALTER, multi-select) | |
| `learning_goals` | `id TEXT PK, learner_id, course_id, target_date, created_at` | |

### Auth & accounts

`auth_sessions` (bearer sessions, `token_hash`, 30-day expiry), `login_history`, `password_reset_tokens`, `email_verification_tokens`, `api_keys`, `audit_log`, `learner_profiles` (username UNIQUE, social links, visibility), `learner_settings` (theme/font/language), `learning_preferences` (daily goals, energy check-in, streak display toggles).

### Analytics

`course_analytics`, `difficulty_analytics`, `error_analytics`, `engagement_analytics`, `velocity_analytics` (per-learner aggregates, updated on activity).

### Social, content & motivation

| Table | Purpose |
|---|---|
| `enrollments` | Course enrollment + status |
| `course_prerequisites` | (course_id, required_course_id, min_mastery_pct) |
| `skill_assessments` | Placement results + recommended start |
| `course_reviews` | Ratings + helpful counts |
| `content_feedback`, `exercise_reports` | User feedback + moderation status |
| `bookmarks`, `learner_notes` | Per-concept saves and notes |
| `notifications` | In-app notifications with `action_url` |
| `achievements` | Badge grants (`badge_type`, `badge_name`) |
| `learning_streaks`, `daily_activity` | Streak counters + per-day activity |
| `study_plans` | Dated study blocks with focus concepts |
| `certificates` | Issued certificates |

**Indexes:** `idx_cs_learner`, `idx_ri_learner`, `idx_ri_due`, `idx_sess_learner`, `idx_si_session`, `idx_lg_learner` plus later-added indexes on newer tables.

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

ALL SQL lives here. Web handlers call these — never write SQL in `web/`. All take `db : *DbClient` as first param unless noted.

| File | Functions |
|---|---|
| `schema.ch` | `init_schema(db)` — all CREATE TABLE + ALTER migrations |
| `courses.ch` | `load_course(courses_dir, course_id) : Course`, `load_course_from_disk`, `list_courses(courses_dir) : vector<Course>` — disk manifest first, hardcoded ELF fallback second |
| `learners.ch` | `create_learner`, `get_learner` |
| `concept_states.ch` | `get_concept_state`, `upsert_concept_state`, `get_all_concept_states` |
| `review_items.ch` | `get_due_review_items`, `get_all_review_items`, `update_review_item`, `insert_review_item` |
| `sessions.ch` | `create_session`, `insert_session`, `finish_session`, `pause_session`, `resume_session`, `abort_session`, `undo_last_item`, `skip_item` |
| `session_items.ch` | `record_session_item`, `get_session_items`, `get_session_stats`, `get_learner_sessions`, `get_all_review_history` |
| `exercises.ch` | `get_exercises_for_concept`, `get_exercise`, `insert_exercise`, `count_exercises` |
| `goals.ch` | `get_learning_goal`, `set_learning_goal`, `delete_learning_goal` |
| `profiles.ch` | `get_profile`, `upsert_profile`, `is_username_available`, `get_profile_by_username` |
| `settings.ch` | `get_settings`, `upsert_settings`, `get_learning_preferences`, `upsert_learning_preferences` |
| `enrollments.ch` | `enroll_learner`, `get_enrollment`, `get_learner_enrollments`, `update_last_accessed`, `complete_enrollment` |
| `feedback.ch` | `submit_feedback`, `get_feedback_for_concept`, `get_all_pending_feedback`, `update_feedback_status`, `report_exercise`, `get_exercise_reports`, `get_all_exercise_reports`, `get_feedback_stats` |
| `prerequisites.ch` | `get_prerequisites`, `add_prerequisite`, `remove_prerequisite`, `check_prerequisites`, `get_missing_prerequisites`, `save_assessment_result`, `get_latest_assessment` |
| `notifications.ch` | `create_notification`, `get_notifications`, `get_unread_count`, `mark_read`, `mark_all_read`, `delete_notification`, `delete_old_notifications` |
| `streaks.ch` | `record_activity`, `get_streak`, `get_weekly_activity` |
| `course_reviews.ch` | `submit_review`, `get_reviews_for_course`, `get_learner_review`, `update_review`, `delete_review`, `mark_helpful`, `get_course_rating_summary` |
| `achievements.ch` | `grant_achievement`, `get_achievements`, `has_achievement`, `get_achievement_count`, `check_and_award_streak`, `check_and_award_milestones`, `run_achievement_checks` |
| `notes.ch` | `create_note`, `update_note`, `delete_note`, `get_notes_for_concept`, `get_notes_for_course`, `search_notes` |
| `certificates.ch` | `issue_certificate`, `get_certificate`, `get_learner_certificates`, `has_certificate` |
| `bookmarks.ch` | `add_bookmark`, `remove_bookmark`, `get_bookmarks`, `get_bookmarks_for_course`, `is_bookmarked` |
| `study_plan.ch` | `create_plan`, `get_plans`, `get_plans_for_date`, `get_plan`, `update_plan_status`, `delete_plan`, `get_upcoming_plans` |
| `analytics_queries.ch` | `query_temporal_hours/weekdays`, `query_retention`, `query_dropoff`, `query_funnel`, `query_platform`, `query_cohorts`, `query_comparative`, and friends — return `underlayer_db::QueryResult` |
| `helpers.ch` | `parse_i64`, `parse_int`, `parse_f64`, `json_str`, `json_i64`, `json_int`, `json_get`, `json_get_str`, `json_get_int` (public — shared across repo files) |

## Web Auth Helpers (web/src/handlers_auth.ch)

```chemical
underlayer_web::auth_get_learner_id(db, req) : string   // bearer token → learner_id ("" if invalid)
underlayer_web::handle_register / handle_login / handle_logout / handle_get_me
underlayer_web::handle_forgot_password / handle_reset_password / handle_verify_email
underlayer_web::handle_login_history
```

## Learning Engine API (learning/src/) — pure functions, no SQL

| File | Functions |
|---|---|
| `fsrs.ch` | `init_fsrs_params`, `fsrs_retrievability(state, elapsed_days)`, `fsrs_next_interval(params, state, rating) : i64`, `fsrs_update_state(params, state, rating) : ReviewState`, `grad_step_interval`, `compute_prediction_error`, `optimize_fsrs_params`, `reset_fsrs_params`, `export_fsrs_params : string`, `log_param_change : string` |
| `session.ch` | `start_review_session(items) : ReviewSession`, `get_current_item(session, out)`, `advance_session`, `is_session_complete : bool` |
| `queue.ch` | `build_review_queue(...)`, `interleave_items(items, strength)`, `compute_adaptive_strength(base, accuracy, streak) : int`, `should_interleave_prereqs`, `get_next_review_items(queue)` |
| `weakness.ch` | `detect_weaknesses(states) : vector<WeaknessReport>`, `suggest_repair`, `compute_weakness_trend`, `detect_weakness_chains`, `cluster_weaknesses`, `predict_weakness : f64`, `should_schedule_repair`, `track_weakness_resolution` |
| `mistakes.ch` | `classify_mistake_pattern(state) : string`, `detect_mistake_patterns(states) : vector<MistakePattern>`, `personalized_feedback(pattern) : string` |
| `health.ch` | `compute_knowledge_health`, `compute_module_health`, `compute_depth_score`, `compute_breadth_score`, `compute_health_goal`, `check_milestones`, `compute_retention_projection`, `identify_knowledge_gaps`, `compute_health_trend`, `compute_health_comparison`, `identify_knowledge_overlap`, `export_health_json : string` |

## Adding a New Endpoint (checklist)

1. Write handler in `web/src/handlers_<area>.ch` (split file if >250 lines)
2. If new SQL is needed: add function to the right `repository/src/<entity>.ch` — never in `web/`
3. If the endpoint is user-scoped: resolve learner via `auth_get_learner_id(db, req)` (bearer token), or accept `learner_id` explicitly for legacy endpoints
4. Register route in `app/main.ch` with capture `(|db|` / `(|&db, &courses_dir|` (both capture styles appear in the codebase)
5. Extract path params by position via `underlayer_core::path_segments()`
6. Add tests in `tests/src/` (unique port, happy + error path) — see `testing` skill
7. Update this skill's route table and `docs/features-complete.md` (check the item off)
8. Verify: `./scripts/test.sh`, then `./scripts/serve.sh` + `curl localhost:9000/api/health`
