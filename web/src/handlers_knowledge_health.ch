// underlayer_web — Knowledge Health & Enrollment API handlers (1.5.20, enrollment).
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // ---- 1.5.20: GET /api/health/knowledge ----
    public func handle_knowledge_health(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var course_id = extract_query_param(req, "course_id")
        if(course_id.size() == 0) { course_id = string("elf") }
        var states = underlayer_repository::get_all_concept_states(db, &learner_id, &course_id)
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var resp = underlayer_learning::export_health_json(&raw health)
        send_json_str(res, &raw resp)
    }

    // ---- 1.5.2-1.5.3: GET /api/health/knowledge/per-module ----
    public func handle_knowledge_health_per_module(db : *DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var course_id = extract_query_param(req, "course_id")
        if(course_id.size() == 0) { course_id = string("elf") }
        var states = underlayer_repository::get_all_concept_states(db, &learner_id, &course_id)
        var course = underlayer_repository::load_course_from_disk(courses_dir, &course_id)
        var resp = string("[")
        var mi : size_t = 0
        while(mi < course.modules.size()) {
            var mod = course.modules.get_ptr(mi)
            if(mi > 0) { resp.append_view(",") }
            var mod_health = underlayer_learning::compute_module_health(&raw states, &raw mod.concepts)
            resp.append_view("{\"module_id\":\"")
            var mid = mod.id.copy()
            resp.append_string(&mid)
            resp.append_view("\",\"title\":\"")
            var mtitle = mod.title.copy()
            resp.append_string(&mtitle)
            resp.append_view("\",\"total_concepts\":")
            var tc = underlayer_core::int_to_string(mod_health.total_concepts as i64)
            resp.append_string(&tc)
            resp.append_view(",\"mastered\":")
            var ma = underlayer_core::int_to_string(mod_health.mastered as i64)
            resp.append_string(&ma)
            resp.append_view(",\"learning\":")
            var lr = underlayer_core::int_to_string(mod_health.learning as i64)
            resp.append_string(&lr)
            resp.append_view(",\"reviewing\":")
            var rv = underlayer_core::int_to_string(mod_health.reviewing as i64)
            resp.append_string(&rv)
            resp.append_view(",\"unlearned\":")
            var ul = underlayer_core::int_to_string(mod_health.unlearned as i64)
            resp.append_string(&ul)
            resp.append_view(",\"health_score\":")
            var hs = underlayer_learning::f64_to_string(mod_health.health_score)
            resp.append_string(&hs)
            resp.append_view("}")
            mi = mi + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

    // ---- 1.5.9: GET /api/health/knowledge/projection ----
    public func handle_knowledge_projection(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var course_id = extract_query_param(req, "course_id")
        if(course_id.size() == 0) { course_id = string("elf") }
        var states = underlayer_repository::get_all_concept_states(db, &learner_id, &course_id)
        var proj = underlayer_learning::compute_retention_projection(&raw states)
        var resp = string("{\"days_30\":")
        var d30 = underlayer_learning::f64_to_string(proj.days_30)
        resp.append_string(&d30)
        resp.append_view(",\"days_60\":")
        var d60 = underlayer_learning::f64_to_string(proj.days_60)
        resp.append_string(&d60)
        resp.append_view(",\"days_90\":")
        var d90 = underlayer_learning::f64_to_string(proj.days_90)
        resp.append_string(&d90)
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

    // ---- Course Enrollment API ----

    // POST /api/courses/:courseId/enroll
    public func handle_enroll_course(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() < 3) {
            var err = string("missing course id")
            send_error(res, 400u, &err)
            return
        }
        var course_id = segments.get_ptr(2).to_string()
        var existing = underlayer_repository::get_enrollment(db, &learner_id, &course_id)
        if(existing.id.size() > 0) {
            var resp = string("{\"ok\":true,\"enrollment_id\":\"")
            var eid = existing.id.copy()
            resp.append_string(&eid)
            resp.append_view("\",\"status\":\"already_enrolled\"}")
            send_json_str(res, &raw resp)
            return
        }
        var enrollment_id = underlayer_repository::enroll_learner(db, &learner_id, &course_id)
        var resp = string("{\"ok\":true,\"enrollment_id\":\"")
        resp.append_string(&enrollment_id)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // GET /api/enrollments
    public func handle_get_enrollments(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var enrollments = underlayer_repository::get_learner_enrollments(db, &learner_id)
        var resp = string("[")
        var ei : size_t = 0
        while(ei < enrollments.size()) {
            if(ei > 0) { resp.append_view(",") }
            var e = enrollments.get_ptr(ei)
            resp.append_view("{\"id\":\"")
            var eid = e.id.copy()
            resp.append_string(&eid)
            resp.append_view("\",\"learner_id\":\"")
            var lid = e.learner_id.copy()
            resp.append_string(&lid)
            resp.append_view("\",\"course_id\":\"")
            var cid = e.course_id.copy()
            resp.append_string(&cid)
            resp.append_view("\",\"enrolled_at\":")
            var ea = underlayer_core::int_to_string(e.enrolled_at)
            resp.append_string(&ea)
            resp.append_view(",\"last_accessed\":")
            var la = underlayer_core::int_to_string(e.last_accessed)
            resp.append_string(&la)
            resp.append_view(",\"completed_at\":")
            var ca = underlayer_core::int_to_string(e.completed_at)
            resp.append_string(&ca)
            resp.append_view(",\"status\":\"")
            var st = e.status.copy()
            resp.append_string(&st)
            resp.append_view("\"}")
            ei = ei + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

    // ---- Helpers ----

    private func extract_query_param(req : &http::Request, key : *char) : string {
        var key_str = string::make_no_len(key)
        var key_sv = key_str.to_view()
        var val = req.query.get(&key_sv)
        var result = string()
        var i : size_t = 0
        while(i < val.size()) { result.append(val.get(i)); i = i + 1 }
        return result
    }

}
