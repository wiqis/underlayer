// underlayer_web — Course prerequisites and skill assessment handlers.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // GET /api/courses/:courseId/prerequisites
    public func handle_get_prerequisites(db : *DbClient, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var prereqs = underlayer_repository::get_prerequisites(db, course_id)
        var body = string("[")
        var i : size_t = 0
        while(i < prereqs.size()) {
            if(i > 0) { body.append_view(",") }
            var prereq = prereqs.get_ptr(i)
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
        send_json_str(res, &raw body)
    }

    // POST /api/courses/:courseId/prerequisites
    public func handle_add_prerequisite(db : *DbClient, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var body_str = read_body(&raw mut req)
        if(body_str.size() == 0) {
            var err = string("empty request body")
            send_error(res, 400u, &err)
            return
        }
        var parse_result = json::parse(body_str.to_view())
        if(parse_result is std::Result.Err) {
            var err = string("invalid JSON")
            send_error(res, 400u, &err)
            return
        }
        var Ok(parsed) = parse_result else unreachable
        var required_id = json_get_str(&raw parsed, "required_course_id")
        var min_mastery = json_get_int(&raw parsed, "min_mastery_pct")
        if(required_id.size() == 0) {
            var err = string("missing required_course_id")
            send_error(res, 400u, &err)
            return
        }
        if(min_mastery <= 0) { min_mastery = 80 }
        underlayer_repository::add_prerequisite(db, course_id, &required_id, min_mastery)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // DELETE /api/courses/:courseId/prerequisites/:requiredId
    public func handle_remove_prerequisite(db : *DbClient, course_id : &string, required_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        underlayer_repository::remove_prerequisite(db, course_id, required_id)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // GET /api/courses/:courseId/can-enroll
    public func handle_can_enroll(db : *DbClient, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
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
                var prereq = missing.get_ptr(i)
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
        send_json_str(res, &raw resp)
    }

    // POST /api/courses/:courseId/assess
    public func handle_skill_assessment(db : *DbClient, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var courses_dir = string("./courses")
        var course = underlayer_repository::load_course(&courses_dir, course_id)
        if(course.id.size() == 0) {
            var err = string("course not found")
            send_error(res, 404u, &err)
            return
        }
        var score = 0
        var total = 0
        var concept_count = course.concepts.size()
        if(concept_count == 0) {
            var resp = string("{\"score\":0,\"total\":0,\"placement\":\"beginner\",\"recommended_start\":\"\"}")
            send_json_str(res, &raw resp)
            return
        }
        var epc : int = 10 / (concept_count as int)
        if(epc < 1) { epc = 1 }
        var ci : size_t = 0
        while(ci < concept_count) {
            var concept = course.concepts.get_ptr(ci)
            var exercises = underlayer_repository::get_exercises_for_concept(db, &concept.id, epc)
            var ei : size_t = 0
            while(ei < exercises.size()) {
                var ex = exercises.get_ptr(ei)
                if(ex.exercise_type.id.equals(string("recognize")) && ex.options.size() > 0) {
                    var correct = false
                    var oi : size_t = 0
                    while(oi < ex.options.size()) {
                        var opt = ex.options.get_ptr(oi)
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
                    var concept = course.concepts.get_ptr(idx as size_t)
                    recommended_start = concept.id.copy()
                } else {
                    var concept = course.concepts.get_ptr(concept_count - 1)
                    recommended_start = concept.id.copy()
                }
            } else if(pct >= 30) {
                placement = string("intermediate")
                var idx : int = (concept_count as int) / 2
                if((idx as size_t) < concept_count) {
                    var concept = course.concepts.get_ptr(idx as size_t)
                    recommended_start = concept.id.copy()
                } else {
                    var concept = course.concepts.get_ptr(0)
                    recommended_start = concept.id.copy()
                }
            } else {
                var concept = course.concepts.get_ptr(0)
                recommended_start = concept.id.copy()
            }
        } else {
            var concept = course.concepts.get_ptr(0)
            recommended_start = concept.id.copy()
        }
        var result = underlayer_repository::SkillAssessmentResult::make()
        result.learner_id = learner_id.copy()
        result.course_id = course_id.copy()
        result.score = score
        result.total = total
        result.placement = placement.copy()
        result.recommended_start = recommended_start.copy()
        underlayer_repository::save_assessment_result(db, &raw result)
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
        send_json_str(res, &raw resp)
    }

    // GET /api/courses/:courseId/assessment
    public func handle_get_assessment(db : *DbClient, course_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
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
        send_json_str(res, &raw resp)
    }

}
