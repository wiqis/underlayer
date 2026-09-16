// underlayer_web — Learning loop handlers (lesson view recording).
// Drives concept_states from real course reading. Anonymous requests are a no-op.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // POST /api/learning/view — mark a concept as viewed/studied.
    // Body: {"course_id":"elf","concept_id":"bytes"}
    public func handle_learning_view(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var anon = string("{\"ok\":true,\"recorded\":false}")
            send_json_str(res, &raw anon)
        } else {
            var body_str = read_body(&raw mut req)
            if(body_str.size() == 0) {
                var err = string("empty request body")
                send_error(res, 400u, &err)
            } else {
                var parse_result = json::parse(body_str.to_view())
                if(parse_result is std::Result.Err) {
                    var err = string("invalid JSON")
                    send_error(res, 400u, &err)
                } else {
                    var Ok(parsed) = parse_result else unreachable
                    var course_id = json_get_str(&raw parsed, "course_id")
                    var concept_id = json_get_str(&raw parsed, "concept_id")
                    if(concept_id.size() == 0 || course_id.size() == 0) {
                        var err = string("course_id and concept_id are required")
                        send_error(res, 400u, &err)
                    } else {
                        var state = underlayer_repository::get_concept_state(db, &learner_id, &concept_id, &course_id)
                        state.learner_id = learner_id.copy()
                        state.concept_id = concept_id.copy()
                        state.course_id = course_id.copy()
                        var not_started = string("not_started")
                        if(state.status.size() == 0) { state.status = string("learning") }
                        else if(state.status.equals(&not_started)) { state.status = string("learning") }
                        state.last_studied = underlayer_core::current_timestamp()
                        underlayer_repository::upsert_concept_state(db, &raw state)
                        underlayer_repository::record_activity(db, &learner_id)
                        var ok = string("{\"ok\":true,\"recorded\":true,\"status\":\"")
                        ok.append_string(&state.status)
                        ok.append_view("\"}")
                        send_json_str(res, &raw ok)
                    }
                }
            }
        }
    }

}
