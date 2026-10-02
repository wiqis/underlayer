// underlayer_web — Feedback a learner FILES, and the one read they may make.
//
// WHY THE ADMIN HALF IS IN ITS OWN FILE (handlers_feedback_admin.ch).  This file
// was 273 lines before this change -- already over the 250-line ceiling -- and
// the split is by authorisation, which is the axis that matters here: everything
// a signed-in learner may do to feedback is here, and everything that would
// cross learners is in the other file where it can only be read as one decision.
//
// THE READ IS OWNER-SCOPED AND THAT IS THE FIX.  `GET
// /api/feedback/concept/:conceptId` was called with a concept id and no
// learner_id at all, so it answered 200 to an anonymous request carrying every
// learner's feedback for that concept: learner_id, message, status,
// admin_notes.  Confirmed by unauthenticated curl.  The empty table is why the
// probe returned `200 []` and looked harmless -- the endpoint was open, the data
// was simply not there yet.
//
// WHY OWNER-SCOPED AND NOT "AUTHENTICATED".  There is no admin role on this
// platform: `learners` is (id, name, email, password_hash, created_at) with no
// role column and no membership table, and handlers_settings.ch has no role
// concept either.  So there is nobody to authenticate AS.  Requiring a token
// without scoping to the owner would have turned an open hole into a
// one-login-and-everybody hole, which is the same defect wearing a hat.
//
// The consequence is recorded, not hidden: with reads scoped to the owner, a
// course author can no longer read the corrections a learner filed about their
// own lesson through this API.  Feedback triage is unreachable.  That is the
// price of there being no reviewer identity to give it to, and it is why the
// cross-learner routes are refused with a message that says so rather than
// quietly returning nothing.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // POST /api/feedback — Submit content feedback
    public func handle_submit_feedback(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
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
        var concept_id = json_get_str(&raw parsed, "concept_id")
        var course_id = json_get_str(&raw parsed, "course_id")
        var feedback_type = json_get_str(&raw parsed, "feedback_type")
        var message = json_get_str(&raw parsed, "message")
        var page_url = json_get_str(&raw parsed, "page_url")
        if(concept_id.size() == 0) {
            var err = string("concept_id is required")
            send_error(res, 400u, &err)
            return
        }
        if(feedback_type.size() == 0) {
            var err = string("feedback_type is required")
            send_error(res, 400u, &err)
            return
        }
        if(message.size() == 0) {
            var err = string("message is required")
            send_error(res, 400u, &err)
            return
        }
        var fb = underlayer_repository::ContentFeedback::make()
        fb.learner_id = learner_id.copy()
        fb.concept_id = concept_id.copy()
        fb.course_id = course_id.copy()
        fb.feedback_type = feedback_type.copy()
        fb.message = message.copy()
        fb.page_url = page_url.copy()
        fb.status = string("pending")
        var fb_id = underlayer_repository::submit_feedback(db, &raw fb)
        var resp = string("{\"ok\":true,\"id\":\"")
        resp.append_string(&fb_id)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // GET /api/feedback/concept/:conceptId — the caller's OWN feedback for a
    // concept.  401 with no token; the repository filters by learner_id so a
    // signed-in learner sees their own rows and only their own rows.
    public func handle_get_concept_feedback(db : *DbClient, concept_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var feedbacks = underlayer_repository::get_feedback_for_learner_concept(db, &learner_id, concept_id)
        var resp = string("[")
        var ri : size_t = 0
        while(ri < feedbacks.size()) {
            if(ri > 0) { resp.append_view(",") }
            var fb = feedbacks.get_ptr(ri)
            resp.append_view("{\"id\":\"")
            resp.append_string(&fb.id)
            resp.append_view("\",\"learner_id\":\"")
            resp.append_string(&fb.learner_id)
            resp.append_view("\",\"concept_id\":\"")
            resp.append_string(&fb.concept_id)
            resp.append_view("\",\"course_id\":\"")
            resp.append_string(&fb.course_id)
            resp.append_view("\",\"feedback_type\":\"")
            resp.append_string(&fb.feedback_type)
            resp.append_view("\",\"message\":\"")
            resp.append_string(&fb.message)
            resp.append_view("\",\"page_url\":\"")
            resp.append_string(&fb.page_url)
            resp.append_view("\",\"status\":\"")
            resp.append_string(&fb.status)
            resp.append_view("\",\"admin_notes\":\"")
            resp.append_string(&fb.admin_notes)
            resp.append_view("\",\"created_at\":")
            var created_str = underlayer_core::int_to_string(fb.created_at)
            resp.append_view(created_str.to_view())
            resp.append_view(",\"updated_at\":")
            var updated_str = underlayer_core::int_to_string(fb.updated_at)
            resp.append_view(updated_str.to_view())
            resp.append_view("}")
            ri = ri + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

    // POST /api/feedback/report-exercise
    public func handle_report_exercise(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
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
        var exercise_id = json_get_str(&raw parsed, "exercise_id")
        var concept_id = json_get_str(&raw parsed, "concept_id")
        var report_type = json_get_str(&raw parsed, "report_type")
        var message = json_get_str(&raw parsed, "message")
        if(exercise_id.size() == 0) {
            var err = string("exercise_id is required")
            send_error(res, 400u, &err)
            return
        }
        if(report_type.size() == 0) {
            var err = string("report_type is required")
            send_error(res, 400u, &err)
            return
        }
        var report = underlayer_repository::ExerciseReport::make()
        report.learner_id = learner_id.copy()
        report.exercise_id = exercise_id.copy()
        report.concept_id = concept_id.copy()
        report.report_type = report_type.copy()
        report.message = message.copy()
        report.status = string("pending")
        var report_id = underlayer_repository::report_exercise(db, &raw report)
        var resp = string("{\"ok\":true,\"id\":\"")
        resp.append_string(&report_id)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // GET /api/feedback/stats — counts by feedback_type across all learners.
    // The ONLY feedback read left that is not owner-scoped, and it is left
    // because it carries no learner identity and no message: an aggregate over
    // a category name.  Nothing in the client calls it.  Reported in
    // docs/audit-2026-10-02-hardening.md as found-and-not-changed.
    public func handle_feedback_stats(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var stats = underlayer_repository::get_feedback_stats(db)
        var resp = string("[")
        var ri : size_t = 0
        while(ri < stats.size()) {
            if(ri > 0) { resp.append_view(",") }
            var s = stats.get_ptr(ri)
            resp.append_view("{\"feedback_type\":\"")
            resp.append_string(&s.feedback_type)
            resp.append_view("\",\"count\":")
            var cnt_str = underlayer_core::int_to_string(s.count as i64)
            resp.append_view(cnt_str.to_view())
            resp.append_view(",\"pending\":")
            var pend_str = underlayer_core::int_to_string(s.pending as i64)
            resp.append_view(pend_str.to_view())
            resp.append_view("}")
            ri = ri + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

}
