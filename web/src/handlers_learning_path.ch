// underlayer_web — Course prerequisites and skill assessment handlers.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // GET /api/courses/:courseId/prerequisites
    public func handle_get_prerequisites(db : *DbClient, course_id : &string, req : &http::Request) : http::Response {
        var prereqs = underlayer_repository::get_prerequisites(db, course_id)
        var body = string("[")
        var i : size_t = 0
        while(i < prereqs.size()) {
            if(i > 0) { body.append_view(",") }
            var prereq = prereqs.at_ref(i)
            body.append_view("{\"course_id\":\"")
            var cid = prereq.course_id.copy()
            body.append_string(&cid)
            body.append_view("\",\"required_course_id\":\"")
            var rid = prereq.required_course_id.copy()
            body.append_string(&rid)
            body.append_view("\",\"min_mastery_pct\":")
            var pct = underlayer_core::int_to_string(prereq.min_mastery_pct as i64)
            body.append_view(pct.to_view())
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]")
        return send_json_str(&body)
    }

    // POST /api/courses/:courseId/prerequisites
    public func handle_add_prerequisite(db : *DbClient, course_id : &string, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        var body_str = read_body(req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            return send_error(400u, &err)
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            return send_error(400u, &err)
        }
        var Ok(parsed) = parse_result else unsafe { unreachable }
        var required_id = json_get_str(&parsed, "required_course_id")
        var min_mastery = json_get_int(&parsed, "min_mastery_pct")
        if(required_id.size() == 0) {
            var err = string("missing required_course_id")
            return send_error(400u, &err)
        }
        if(min_mastery <= 0) { min_mastery = 80 }
        underlayer_repository::add_prerequisite(db, course_id, &required_id, min_mastery)
        var resp = string("{\"ok\":true}")
        return send_json_str(&resp)
    }

    // DELETE /api/courses/:courseId/prerequisites/:requiredId
    public func handle_remove_prerequisite(db : *DbClient, course_id : &string, required_id : &string, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        underlayer_repository::remove_prerequisite(db, course_id, required_id)
        var resp = string("{\"ok\":true}")
        return send_json_str(&resp)
    }

    // GET /api/courses/:courseId/can-enroll
    public func handle_can_enroll(db : *DbClient, course_id : &string, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        var can = underlayer_repository::check_prerequisites(db, &learner_id, course_id)
        var resp = string("{\"can_enroll\":")
        if(can) { resp.append_view("true") } else { resp.append_view("false") }
        if(!can) {
            var missing = underlayer_repository::get_missing_prerequisites(db, &learner_id, course_id)
            resp.append_view(",\"missing\":[")
            var i : size_t = 0
            while(i < missing.size()) {
                if(i > 0) { resp.append_view(",") }
                var prereq = missing.at_ref(i)
                resp.append_view("{\"required_course_id\":\"")
                var rid = prereq.required_course_id.copy()
                resp.append_string(&rid)
                resp.append_view("\",\"min_mastery_pct\":")
                var pct = underlayer_core::int_to_string(prereq.min_mastery_pct as i64)
                resp.append_view(pct.to_view())
                resp.append_view("}")
                i = i + 1
            }
            resp.append_view("]")
        }
        resp.append_view("}")
        return send_json_str(&resp)
    }

    // POST /api/courses/:courseId/assess
    public func handle_skill_assessment(db : *DbClient, course_id : &string, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        var courses_dir = string("./courses")
        var course = underlayer_repository::load_course(&courses_dir, course_id)
        if(course.id.size() == 0) {
            var err = string("course not found")
            return send_error(404u, &err)
        }
        var score = 0
        var total = 0
        var concept_count = course.concepts.size()
        if(concept_count == 0) {
            var resp = string("{\"score\":0,\"total\":0,\"placement\":\"beginner\",\"recommended_start\":\"\"}")
            return send_json_str(&resp)
        }
        var epc : int = 10 / (concept_count as int)
        if(epc < 1) { epc = 1 }
        var ci : size_t = 0
        while(ci < concept_count) {
            var concept = course.concepts.at_ref(ci)
            var exercises = underlayer_repository::get_exercises_for_concept(db, &concept.id, epc)
            var ei : size_t = 0
            while(ei < exercises.size()) {
                var ex = exercises.at_ref(ei)
                if(ex.exercise_type.id.equals(string("recognize")) && ex.options.size() > 0) {
                    var correct = false
                    var oi : size_t = 0
                    while(oi < ex.options.size()) {
                        var opt = ex.options.at_ref(oi)
                        if(opt.to_view().equals(ex.answer.to_view())) { correct = true }
                        oi = oi + 1
                    }
                    if(correct) { score = score + 1 }
                    total = total + 1
                }
                ei = ei + 1
            }
            ci = ci + 1
        }
        var placement = string("beginner")
        var recommended_start = string()
        if(total > 0) {
            var pct = (score * 100) / total
            if(pct > 70) {
                placement = string("advanced")
                var idx : int = (concept_count as int) * 2 / 3
                if((idx as size_t) < concept_count) {
                    var concept = course.concepts.at_ref(idx as size_t)
                    recommended_start = concept.id.copy()
                } else {
                    var concept = course.concepts.at_ref(concept_count - 1)
                    recommended_start = concept.id.copy()
                }
            } else if(pct >= 30) {
                placement = string("intermediate")
                var idx : int = (concept_count as int) / 2
                if((idx as size_t) < concept_count) {
                    var concept = course.concepts.at_ref(idx as size_t)
                    recommended_start = concept.id.copy()
                } else {
                    var concept = course.concepts.at_ref(0)
                    recommended_start = concept.id.copy()
                }
            } else {
                var concept = course.concepts.at_ref(0)
                recommended_start = concept.id.copy()
            }
        } else {
            var concept = course.concepts.at_ref(0)
            recommended_start = concept.id.copy()
        }
        var result = underlayer_repository::SkillAssessmentResult::make()
        result.learner_id = learner_id.copy()
        result.course_id = course_id.copy()
        result.score = score
        result.total = total
        result.placement = placement.copy()
        result.recommended_start = recommended_start.copy()
        underlayer_repository::save_assessment_result(db, &result)
        var resp = string("{\"score\":")
        var score_str = underlayer_core::int_to_string(score as i64)
        resp.append_view(score_str.to_view())
        resp.append_view(",\"total\":")
        var total_str = underlayer_core::int_to_string(total as i64)
        resp.append_view(total_str.to_view())
        resp.append_view(",\"placement\":\"")
        resp.append_string(&placement)
        resp.append_view("\",\"recommended_start\":\"")
        resp.append_string(&recommended_start)
        resp.append_view("\"}")
        return send_json_str(&resp)
    }

    // GET /api/courses/:courseId/assessment
    public func handle_get_assessment(db : *DbClient, course_id : &string, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        var result = underlayer_repository::get_latest_assessment(db, &learner_id, course_id)
        var resp = string("{\"score\":")
        var score_str = underlayer_core::int_to_string(result.score as i64)
        resp.append_view(score_str.to_view())
        resp.append_view(",\"total\":")
        var total_str = underlayer_core::int_to_string(result.total as i64)
        resp.append_view(total_str.to_view())
        resp.append_view(",\"placement\":\"")
        resp.append_string(&result.placement)
        resp.append_view("\",\"recommended_start\":\"")
        resp.append_string(&result.recommended_start)
        resp.append_view("\",\"created_at\":")
        var ts = underlayer_core::int_to_string(result.created_at)
        resp.append_view(ts.to_view())
        resp.append_view("}")
        return send_json_str(&resp)
    }

}
