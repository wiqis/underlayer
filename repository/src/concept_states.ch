// underlayer_repository — Concept state CRUD.
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_models::ConceptState
using underlayer_models::AggregateStats

public namespace underlayer_repository {

    public func get_concept_state(db : *DbClient, learner_id : &string, concept_id : &string, course_id : &string) : ConceptState {
        var state = ConceptState::make()
        var sql = string("SELECT status, attempts, correct, streak, last_studied, next_review, difficulty_rating FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND concept_id = '")
        sql.append_string(concept_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 7) {
                state.learner_id = learner_id.copy()
                state.concept_id = concept_id.copy()
                state.course_id = course_id.copy()
                state.status = row.vals.get_ptr(0).copy()
                state.attempts = parse_i64(row.vals.get_ptr(1).to_view()) as int
                state.correct = parse_i64(row.vals.get_ptr(2).to_view()) as int
                state.streak = parse_i64(row.vals.get_ptr(3).to_view()) as int
                state.last_studied = parse_i64(row.vals.get_ptr(4).to_view())
                state.next_review = parse_i64(row.vals.get_ptr(5).to_view())
            }
        }
        return state
    }

    public func upsert_concept_state(db : *DbClient, state : *ConceptState) {
        var sql = string("INSERT OR REPLACE INTO concept_states (learner_id, concept_id, course_id, status, attempts, correct, streak, last_studied, next_review, difficulty_rating) VALUES ('")
        var lid = state.learner_id.copy()
        sql.append_string(&lid)
        sql.append_view("', '")
        var cid = state.concept_id.copy()
        sql.append_string(&cid)
        sql.append_view("', '")
        var crsid = state.course_id.copy()
        sql.append_string(&crsid)
        sql.append_view("', '")
        var sstat = state.status.copy()
        sql.append_string(&sstat)
        sql.append_view("', ")
        var a = underlayer_core::int_to_string(state.attempts as i64)
        sql.append_view(a.to_view())
        sql.append_view(", ")
        var b = underlayer_core::int_to_string(state.correct as i64)
        sql.append_view(b.to_view())
        sql.append_view(", ")
        var c = underlayer_core::int_to_string(state.streak as i64)
        sql.append_view(c.to_view())
        sql.append_view(", ")
        var d = underlayer_core::int_to_string(state.last_studied)
        sql.append_view(d.to_view())
        sql.append_view(", ")
        var e = underlayer_core::int_to_string(state.next_review)
        sql.append_view(e.to_view())
        sql.append_view(", ")
        var f = underlayer_core::int_to_string(state.difficulty_rating as i64)
        sql.append_view(f.to_view())
        sql.append_view(".0)")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_all_concept_states(db : *DbClient, learner_id : &string, course_id : &string) : vector<ConceptState> {
        var states = vector<ConceptState>()
        var sql = string("SELECT concept_id, status, attempts, correct, streak, last_studied, next_review, difficulty_rating FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 8) {
                var state = ConceptState::make()
                state.learner_id = learner_id.copy()
                state.concept_id = row.vals.get_ptr(0).copy()
                state.course_id = course_id.copy()
                state.status = row.vals.get_ptr(1).copy()
                state.attempts = parse_i64(row.vals.get_ptr(2).to_view()) as int
                state.correct = parse_i64(row.vals.get_ptr(3).to_view()) as int
                state.streak = parse_i64(row.vals.get_ptr(4).to_view()) as int
                state.last_studied = parse_i64(row.vals.get_ptr(5).to_view())
                state.next_review = parse_i64(row.vals.get_ptr(6).to_view())
                states.push(state)
            }
            ri = ri + 1
        }
        return states
    }

    // Aggregate concept stats across ALL learners for anonymous comparison.
    public func get_aggregate_concept_stats(db : *DbClient, concept_id : &string, course_id : &string) : AggregateStats {
        var stats = AggregateStats::make()
        var sql = string("SELECT SUM(attempts) as total_attempts, SUM(correct) as total_correct, COUNT(*) as learner_count FROM concept_states WHERE concept_id = '")
        sql.append_string(concept_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() >= 3) {
                stats.total_attempts = parse_i64(row.vals.get_ptr(0).to_view()) as i64
                stats.total_correct = parse_i64(row.vals.get_ptr(1).to_view()) as i64
                stats.learner_count = parse_i64(row.vals.get_ptr(2).to_view()) as i64
                if(stats.total_attempts > 0) {
                    stats.accuracy = (stats.total_correct as f64) / (stats.total_attempts as f64)
                }
                if(stats.total_attempts > 0 && stats.total_correct < stats.total_attempts) {
                    stats.average_severity = ((stats.total_attempts - stats.total_correct) as f64) / (stats.total_attempts as f64) * 100.0
                }
            }
        }
        return stats
    }

    // Count of concepts the learner has mastered, across all courses.
    public func count_mastered_concepts(db : *DbClient, learner_id : &string) : int {
        var sql = string("SELECT COUNT(*) FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND status = 'mastered'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                return parse_i64(row.vals.get_ptr(0).to_view()) as int
            }
        }
        return 0
    }

    // Total attempts the learner has made, across all courses.
    public func count_total_attempts(db : *DbClient, learner_id : &string) : int {
        var sql = string("SELECT COALESCE(SUM(attempts), 0) FROM concept_states WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        if(result.rows.size() > 0) {
            var row = result.rows.get_ptr(0)
            if(row.vals.size() > 0) {
                return parse_i64(row.vals.get_ptr(0).to_view()) as int
            }
        }
        return 0
    }

}
