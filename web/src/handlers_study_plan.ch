// underlayer_web — Study planner handlers.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // POST /api/study-plans — Create a study plan
    public func handle_create_study_plan(db : *DbClient, req : &http::Request) : http::Response {
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
        var course_id = json_get_str(&parsed, "course_id")
        var plan_date = json_get_str(&parsed, "plan_date")
        var start_hour = json_get_int(&parsed, "start_hour")
        var duration_minutes = json_get_int(&parsed, "duration_minutes")
        var focus_concepts = json_get_str(&parsed, "focus_concepts")
        if(course_id.size() == 0) {
            var err = string("course_id is required")
            return send_error(400u, &err)
        }
        if(plan_date.size() == 0) {
            var err = string("plan_date is required")
            return send_error(400u, &err)
        }
        if(duration_minutes <= 0) { duration_minutes = 30 }
        var plan_id = underlayer_repository::create_plan(db, &learner_id, &course_id, &plan_date, start_hour, duration_minutes, &focus_concepts)
        var resp = string("{\"ok\":true,\"id\":\"")
        resp.append_view(plan_id.to_view())
        resp.append_view("\"}")
        return send_json_str(&resp)
    }

    // GET /api/study-plans — List all plans for current user
    public func handle_get_study_plans(db : *DbClient, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        var plans = underlayer_repository::get_plans(db, &learner_id)
        var resp = string("[")
        var i : size_t = 0
        while(i < plans.size()) {
            if(i > 0) { resp.append_view(",") }
            var p = plans.at_ref(i)
            resp.append_view("{\"id\":\"")
            resp.append_string(&p.id)
            resp.append_view("\",\"learner_id\":\"")
            resp.append_string(&p.learner_id)
            resp.append_view("\",\"course_id\":\"")
            resp.append_string(&p.course_id)
            resp.append_view("\",\"plan_date\":\"")
            resp.append_string(&p.plan_date)
            resp.append_view("\",\"start_hour\":")
            var hour_str = underlayer_core::int_to_string(p.start_hour)
            resp.append_view(hour_str.to_view())
            resp.append_view(",\"duration_minutes\":")
            var dur_str = underlayer_core::int_to_string(p.duration_minutes)
            resp.append_view(dur_str.to_view())
            resp.append_view(",\"focus_concepts\":\"")
            resp.append_string(&p.focus_concepts)
            resp.append_view("\",\"status\":\"")
            resp.append_string(&p.status)
            resp.append_view("\",\"created_at\":")
            var ts_str = underlayer_core::int_to_string(p.created_at)
            resp.append_view(ts_str.to_view())
            resp.append_view("}")
            i = i + 1
        }
        resp.append_view("]")
        return send_json_str(&resp)
    }

    // PUT /api/study-plans/:id — Update plan status
    public func handle_update_study_plan(db : *DbClient, plan_id : &string, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        // Verify ownership
        var plan = underlayer_repository::get_plan(db, plan_id)
        if(plan.id.size() == 0) {
            var err = string("plan not found")
            return send_error(404u, &err)
        }
        if(!plan.learner_id.equals(&learner_id)) {
            var err = string("forbidden")
            return send_error(403u, &err)
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
        var status = json_get_str(&parsed, "status")
        if(status.size() == 0) {
            var err = string("status is required")
            return send_error(400u, &err)
        }
        // Validate status value
        var valid = status.equals(string("planned")) || status.equals(string("completed")) || status.equals(string("skipped"))
        if(!valid) {
            var err = string("status must be planned, completed, or skipped")
            return send_error(400u, &err)
        }
        underlayer_repository::update_plan_status(db, plan_id, &status)
        var resp = string("{\"ok\":true}")
        return send_json_str(&resp)
    }

    // DELETE /api/study-plans/:id — Delete a study plan
    public func handle_delete_study_plan(db : *DbClient, plan_id : &string, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            return send_error(401u, &err)
        }
        // Verify ownership
        var plan = underlayer_repository::get_plan(db, plan_id)
        if(plan.id.size() == 0) {
            var err = string("plan not found")
            return send_error(404u, &err)
        }
        if(!plan.learner_id.equals(&learner_id)) {
            var err = string("forbidden")
            return send_error(403u, &err)
        }
        underlayer_repository::delete_plan(db, plan_id)
        var resp = string("{\"ok\":true}")
        return send_json_str(&resp)
    }

}
