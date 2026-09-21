// underlayer_repository — Course prerequisites and skill assessment.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_repository {

    public struct CoursePrerequisite {
        var course_id : string
        var required_course_id : string
        var min_mastery_pct : int

        @make
        func make() : CoursePrerequisite {
            return CoursePrerequisite { course_id = string(), required_course_id = string(), min_mastery_pct = 0 }
        }
    }

    public struct SkillAssessmentResult {
        var learner_id : string
        var course_id : string
        var score : int
        var total : int
        var placement : string
        var recommended_start : string
        var created_at : i64

        @make
        func make() : SkillAssessmentResult {
            return SkillAssessmentResult { learner_id = string(), course_id = string(), score = 0, total = 0, placement = string(), recommended_start = string(), created_at = 0 }
        }
    }

    public func get_prerequisites(db : *DbClient, course_id : &string) : vector<CoursePrerequisite> {
        var prereqs = vector<CoursePrerequisite>()
        var sql = string("SELECT course_id, required_course_id, min_mastery_pct FROM course_prerequisites WHERE course_id = '")
        sql.append_string(course_id)
        sql.append_view("'")
        var result = underlayer_db::query_sql(db, &raw sql)
        var ri : size_t = 0
        while(ri < result.rows.size()) {
            var row = result.rows.get_ptr(ri)
            if(row.vals.size() >= 3) {
                var prereq = CoursePrerequisite::make()
                prereq.course_id = row.vals.get_ptr(0).copy()
                prereq.required_course_id = row.vals.get_ptr(1).copy()
                prereq.min_mastery_pct = parse_int(row.vals.get_ptr(2).to_view())
                prereqs.push(prereq)
            }
            ri = ri + 1
        }
        return prereqs
    }

    public func add_prerequisite(db : *DbClient, course_id : &string, required_course_id : &string, min_mastery_pct : int) {
        var sql = string("INSERT OR REPLACE INTO course_prerequisites (course_id, required_course_id, min_mastery_pct) VALUES ('")
        sql.append_string(course_id)
        sql.append_view("', '")
        sql.append_string(required_course_id)
        sql.append_view("', ")
        var pct_str = underlayer_core::int_to_string(min_mastery_pct as i64)
        sql.append_view(pct_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func remove_prerequisite(db : *DbClient, course_id : &string, required_course_id : &string) {
        var sql = string("DELETE FROM course_prerequisites WHERE course_id = '")
        sql.append_string(course_id)
        sql.append_view("' AND required_course_id = '")
        sql.append_string(required_course_id)
        sql.append_view("'")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func check_prerequisites(db : *DbClient, learner_id : &string, course_id : &string) : bool {
        var prereqs = get_prerequisites(db, course_id)
        if(prereqs.size() == 0) { return true }
        var i : size_t = 0
        while(i < prereqs.size()) {
            var prereq = prereqs.get_ptr(i)
            var req_id = prereq.required_course_id.copy()
            var enrollment = get_enrollment(db, learner_id, &req_id)
            if(enrollment.status.equals(string("completed"))) { i = i + 1; continue }
            var states = get_all_concept_states(db, learner_id, &req_id)
            if(states.size() == 0) { return false }
            var mastered = 0
            var total_states = states.size()
            var si : size_t = 0
            while(si < states.size()) {
                var state = states.get_ptr(si)
                if(state.attempts > 0 && state.correct > 0) {
                    var mastery = (state.correct * 100) / state.attempts
                    if(mastery >= prereq.min_mastery_pct) { mastered = mastered + 1 }
                }
                si = si + 1
            }
            if(total_states > 0) {
                var pct = (mastered * 100) / (total_states as int)
                if(pct < prereq.min_mastery_pct) { return false }
            } else {
                return false
            }
            i = i + 1
        }
        return true
    }

    public func get_missing_prerequisites(db : *DbClient, learner_id : &string, course_id : &string) : vector<CoursePrerequisite> {
        var prereqs = get_prerequisites(db, course_id)
        var missing = vector<CoursePrerequisite>()
        if(prereqs.size() == 0) { return missing }
        var i : size_t = 0
        while(i < prereqs.size()) {
            var prereq = prereqs.get_ptr(i)
            var req_id = prereq.required_course_id.copy()
            var enrollment = get_enrollment(db, learner_id, &req_id)
            if(enrollment.status.equals(string("completed"))) { i = i + 1; continue }
            var states = get_all_concept_states(db, learner_id, &req_id)
            var met = false
            if(states.size() > 0) {
                var mastered = 0
                var total_states = states.size()
                var si : size_t = 0
                while(si < states.size()) {
                    var state = states.get_ptr(si)
                    if(state.attempts > 0 && state.correct > 0) {
                        var mastery = (state.correct * 100) / state.attempts
                        if(mastery >= prereq.min_mastery_pct) { mastered = mastered + 1 }
                    }
                    si = si + 1
                }
                if(total_states > 0) {
                    var pct = (mastered * 100) / (total_states as int)
                    if(pct >= prereq.min_mastery_pct) { met = true }
                }
            }
            if(!met) {
                var missing_prereq = CoursePrerequisite::make()
                missing_prereq.course_id = prereq.course_id.copy()
                missing_prereq.required_course_id = prereq.required_course_id.copy()
                missing_prereq.min_mastery_pct = prereq.min_mastery_pct
                missing.push(missing_prereq)
            }
            i = i + 1
        }
        return missing
    }

    public func save_assessment_result(db : *DbClient, result : *SkillAssessmentResult) {
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        var sql = string("INSERT INTO skill_assessments (learner_id, course_id, score, total, placement, recommended_start, created_at) VALUES ('")
        sql.append_string(&result.learner_id)
        sql.append_view("', '")
        sql.append_string(&result.course_id)
        sql.append_view("', ")
        var score_str = underlayer_core::int_to_string(result.score as i64)
        sql.append_view(score_str.to_view())
        sql.append_view(", ")
        var total_str = underlayer_core::int_to_string(result.total as i64)
        sql.append_view(total_str.to_view())
        sql.append_view(", '")
        sql.append_string(&result.placement)
        sql.append_view("', '")
        sql.append_string(&result.recommended_start)
        sql.append_view("', ")
        sql.append_view(now_str.to_view())
        sql.append_view(")")
        underlayer_db::exec_sql(db, &raw sql)
    }

    public func get_latest_assessment(db : *DbClient, learner_id : &string, course_id : &string) : SkillAssessmentResult {
        var result = SkillAssessmentResult::make()
        var sql = string("SELECT learner_id, course_id, score, total, placement, recommended_start, created_at FROM skill_assessments WHERE learner_id = '")
        sql.append_string(learner_id)
        sql.append_view("' AND course_id = '")
        sql.append_string(course_id)
        sql.append_view("' ORDER BY created_at DESC LIMIT 1")
        var query_result = underlayer_db::query_sql(db, &raw sql)
        if(query_result.rows.size() > 0) {
            var row = query_result.rows.get_ptr(0)
            if(row.vals.size() >= 7) {
                result.learner_id = row.vals.get_ptr(0).copy()
                result.course_id = row.vals.get_ptr(1).copy()
                result.score = parse_int(row.vals.get_ptr(2).to_view())
                result.total = parse_int(row.vals.get_ptr(3).to_view())
                result.placement = row.vals.get_ptr(4).copy()
                result.recommended_start = row.vals.get_ptr(5).copy()
                result.created_at = parse_i64(row.vals.get_ptr(6).to_view())
            }
        }
        return result
    }

}
