// underlayer_repository — Analytics queries (P2 6.2.4-6.2.7, 6.2.10-6.2.12, 6.2.15).
// All SQL for platform/temporal/retention/funnel/dropoff/cohort/device/compare
// analytics lives here; web handlers only format JSON.
using std::string
using underlayer_db::DbClient

public namespace underlayer_repository {

    // 6.2.6: Session counts bucketed by hour-of-day (UTC hour 0-23)
    public func query_temporal_hours(db : *DbClient, learner_id : &string) : underlayer_db::QueryResult {
        var sql = string("SELECT (start_time / 3600) % 24 AS hour, COUNT(*) AS sessions FROM sessions WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' GROUP BY hour ORDER BY hour ASC")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.6: Session counts bucketed by day-of-week (0=Sunday .. 6=Saturday)
    // Epoch day 0 (1970-01-01) was a Thursday, so add 4 to align.
    public func query_temporal_weekdays(db : *DbClient, learner_id : &string) : underlayer_db::QueryResult {
        var sql = string("SELECT (start_time / 86400 + 4) % 7 AS dow, COUNT(*) AS sessions FROM sessions WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' GROUP BY dow ORDER BY dow ASC")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.12: Retention — active days vs span since first session
    public func query_retention(db : *DbClient, learner_id : &string) : underlayer_db::QueryResult {
        var sql = string("SELECT COUNT(DISTINCT start_time / 86400) AS active_days, MIN(start_time) AS first_session, MAX(start_time) AS last_session, COUNT(*) AS total_sessions FROM sessions WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("'")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.12: Distinct active weeks (for weekly return rate)
    public func query_retention_weeks(db : *DbClient, learner_id : &string) : underlayer_db::QueryResult {
        var sql = string("SELECT COUNT(DISTINCT start_time / 604800) AS active_weeks FROM sessions WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("'")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.10: Drop-off — started concepts ordered by staleness (quit candidates)
    public func query_dropoff(db : *DbClient, learner_id : &string, course_id : &string) : underlayer_db::QueryResult {
        var sql = string("SELECT concept_id, status, attempts, correct, last_studied FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("' AND attempts > 0 AND status != 'mastered' ORDER BY last_studied ASC LIMIT 20")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.11: Funnel — per-learner stage booleans in one row
    public func query_funnel(db : *DbClient, learner_id : &string) : underlayer_db::QueryResult {
        var sql = string("SELECT (SELECT COUNT(*) FROM learners WHERE id = '")
        sql.append_string(learner_id)
        sql.append_view("') AS registered, (SELECT COUNT(DISTINCT concept_id) FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND attempts > 0) AS concepts_attempted, (SELECT COUNT(*) FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND status = 'mastered') AS concepts_mastered, (SELECT COUNT(*) FROM sessions WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("') AS sessions_count")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.4: Platform-wide totals
    public func query_platform(db : *DbClient) : underlayer_db::QueryResult {
        var sql = string("SELECT (SELECT COUNT(*) FROM learners) AS learners, (SELECT COUNT(*) FROM sessions) AS sessions, (SELECT COALESCE(SUM(exercises_correct), 0) FROM sessions) AS correct, (SELECT COALESCE(SUM(exercises_attempted), 0) FROM sessions) AS attempted, (SELECT COUNT(DISTINCT learner_id) FROM sessions WHERE start_time >= (SELECT COALESCE(MAX(start_time), 0) FROM sessions) - 604800) AS active_last_7d")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.5: Cohorts — learners grouped by registration week
    public func query_cohorts(db : *DbClient) : underlayer_db::QueryResult {
        var sql = string("SELECT (created_at / 604800) * 604800 AS week_start, COUNT(*) AS learners FROM learners WHERE created_at > 0 GROUP BY week_start ORDER BY week_start ASC")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.5: Average sessions per learner per cohort week (for cohort comparison)
    public func query_cohort_sessions(db : *DbClient) : underlayer_db::QueryResult {
        var sql = string("SELECT (l.created_at / 604800) * 604800 AS week_start, COUNT(DISTINCT s.learner_id) AS active_learners, COUNT(s.id) AS sessions FROM learners l LEFT JOIN sessions s ON s.learner_id = l.id WHERE l.created_at > 0 GROUP BY week_start ORDER BY week_start ASC")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.7: Device analytics — user agents from login history
    public func query_login_agents(db : *DbClient, learner_id : &string) : underlayer_db::QueryResult {
        var sql = string("SELECT user_agent, COUNT(*) AS logins FROM login_history WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' GROUP BY user_agent ORDER BY logins DESC LIMIT 20")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.15: Comparative — learner accuracy vs platform average
    public func query_comparative(db : *DbClient, learner_id : &string) : underlayer_db::QueryResult {
        var sql = string("SELECT (SELECT COALESCE(SUM(correct), 0) FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("') AS my_correct, (SELECT COALESCE(SUM(attempts), 0) FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("') AS my_attempts, (SELECT COALESCE(SUM(correct), 0) FROM concept_states) AS all_correct, (SELECT COALESCE(SUM(attempts), 0) FROM concept_states) AS all_attempts, (SELECT COUNT(DISTINCT learner_id) FROM concept_states) AS learner_count")
        return underlayer_db::query_sql(db, &raw sql)
    }

    // 6.2.15: Per-learner accuracy list (to position the learner among peers)
    public func query_learner_accuracies(db : *DbClient) : underlayer_db::QueryResult {
        var sql = string("SELECT learner_id, SUM(correct) AS c, SUM(attempts) AS a FROM concept_states WHERE attempts > 0 GROUP BY learner_id")
        return underlayer_db::query_sql(db, &raw sql)
    }

}
