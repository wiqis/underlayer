// underlayer_web — operator-gated feedback triage (H9).
//
// WHAT CHANGED. These routes used to refuse EVERY caller (401 anonymous, 403
// signed-in) because learners have no role column and no reviewer identity
// existed. H9 supplies one WITHOUT adding a role to `learners`: the server
// resolves the caller's existing session, maps it to a stable identity
// (`account_user_id` or local id), and checks it against the secret-store
// `UL_OPERATOR_IDS` allow-list using a constant-time comparison. No request
// field can make a learner an operator.
//
// EVERY SUCCESSFUL OPERATOR ACTION writes one `audit_log` row with the actor,
// the request id and the peer address. A normal learner still gets 403, and
// their owner-scoped read (GET /api/feedback/concept/:conceptId) still cannot
// see another learner's report. There is no admin UI and no Admin/CMS
// checklist tick in this change.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // The shared gate lives in session_guard.ch; this file only decides which
    // action string is audited for each route.

    private func append_json_field(out : &mut string, key : &string_view, value : &string) {
        out.append_view(",\"")
        out.append_view(key)
        out.append_view("\":\"")
        var escaped = underlayer_core::json_escape(&value.to_view())
        out.append_view(escaped.to_view())
        out.append('"')
    }

    private func feedback_rows_json(rows : &vector<underlayer_repository::ContentFeedback>) : string {
        var body = string("[")
        var i : size_t = 0
        while(i < rows.size()) {
            if(i > 0) { body.append_view(",") }
            var fb = rows.at_ref(i)
            body.append_view("{\"id\":\"")
            var escaped = underlayer_core::json_escape(&fb.id.to_view())
            body.append_view(escaped.to_view())
            body.append('"')
            append_json_field(&mut body, string_view("learner_id"), &fb.learner_id)
            append_json_field(&mut body, string_view("concept_id"), &fb.concept_id)
            append_json_field(&mut body, string_view("course_id"), &fb.course_id)
            append_json_field(&mut body, string_view("feedback_type"), &fb.feedback_type)
            append_json_field(&mut body, string_view("message"), &fb.message)
            append_json_field(&mut body, string_view("status"), &fb.status)
            append_json_field(&mut body, string_view("admin_notes"), &fb.admin_notes)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]")
        return body
    }

    private func report_rows_json(rows : &vector<underlayer_repository::ExerciseReport>) : string {
        var body = string("[")
        var i : size_t = 0
        while(i < rows.size()) {
            if(i > 0) { body.append_view(",") }
            var rep = rows.at_ref(i)
            body.append_view("{\"id\":\"")
            var escaped = underlayer_core::json_escape(&rep.id.to_view())
            body.append_view(escaped.to_view())
            body.append('"')
            append_json_field(&mut body, string_view("learner_id"), &rep.learner_id)
            append_json_field(&mut body, string_view("exercise_id"), &rep.exercise_id)
            append_json_field(&mut body, string_view("concept_id"), &rep.concept_id)
            append_json_field(&mut body, string_view("report_type"), &rep.report_type)
            append_json_field(&mut body, string_view("message"), &rep.message)
            append_json_field(&mut body, string_view("status"), &rep.status)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]")
        return body
    }

    // GET /api/feedback/admin — every pending content report, operator only.
    public func handle_get_admin_feedback(db : *DbClient, req : &http::Request) : http::Response {
        var details = string("GET /api/feedback/admin")
        var gate = require_operator(db, req, string("feedback.admin.list"), &details)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return refusal
        }
        var rows = underlayer_repository::get_all_pending_feedback(db)
        var body = feedback_rows_json(&rows)
        return send_json_str(&body)
    }

    // GET /api/feedback/admin/reports — every exercise report, operator only.
    public func handle_get_admin_reports(db : *DbClient, req : &http::Request) : http::Response {
        var details = string("GET /api/feedback/admin/reports")
        var gate = require_operator(db, req, string("feedback.admin.reports"), &details)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return refusal
        }
        var rows = underlayer_repository::get_all_exercise_reports(db)
        var body = report_rows_json(&rows)
        return send_json_str(&body)
    }

    // PUT /api/feedback/:id/status — mark one item fixed/resolved/rejected.
    public func handle_update_feedback_status(db : *DbClient, feedback_id : &string, req : &http::Request) : http::Response {
        var details = string("PUT /api/feedback/:id/status id=")
        details.append_string(feedback_id)
        var gate = require_operator(db, req, string("feedback.admin.status"), &details)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return refusal
        }
        var body_str = read_body(req)
        var parsed_result = json::parse(body_str.to_view())
        if(parsed_result is std::Result.Err) {
            var err = string("invalid JSON")
            return send_error(400u, &err)
        }
        var Ok(parsed) = parsed_result else unsafe { unreachable }
        var status = json_get_str(&parsed, "status")
        var note = json_get_str(&parsed, "admin_notes")
        if(status.empty()) {
            var err = string("status is required")
            return send_error(400u, &err)
        }
        underlayer_repository::update_feedback_status(db, feedback_id, &status, &note)
        var extra = string(" status=")
        extra.append_string(&status)
        details.append_view(extra.to_view())
        var rid = operator_request_id(req)
        var caller = auth_get_learner_id(db, req)
        var actor = underlayer_repository::operator_identity(db, &caller)
        var peer = req.remote.copy()
        underlayer_repository::write_operator_audit(db, &actor, &rid, &peer, string("feedback.admin.status.wrote"), &details)
        var resp = string("{\"ok\":true,\"id\":\"")
        var escaped = underlayer_core::json_escape(&feedback_id.to_view())
        resp.append_view(escaped.to_view())
        resp.append_view("\",\"status\":\"")
        var st_esc = underlayer_core::json_escape(&status.to_view())
        resp.append_view(st_esc.to_view())
        resp.append_view("\"}")
        return send_json_str(&resp)
    }

}
