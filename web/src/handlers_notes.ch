// underlayer_web — Notes API handlers.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // POST /api/notes — Create a note
    public func handle_create_note(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
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
                    var concept_id = json_get_str(&raw parsed, "concept_id")
                    var course_id = json_get_str(&raw parsed, "course_id")
                    var content = json_get_str(&raw parsed, "content")
                    var section_ref = json_get_str(&raw parsed, "section_ref")
                    if(concept_id.size() == 0) {
                        var err = string("concept_id is required")
                        send_error(res, 400u, &err)
                    } else {
                        if(content.size() == 0) {
                            var err = string("content is required")
                            send_error(res, 400u, &err)
                        } else {
                            var note_id = underlayer_repository::create_note(db, &learner_id, &concept_id, &course_id, &content, &section_ref)
                            var resp = string("{\"ok\":true,\"id\":\"")
                            resp.append_string(&note_id)
                            resp.append_view("\"}")
                            send_json_str(res, &raw resp)
                        }
                    }
                }
            }
        }
    }

    // PUT /api/notes/:id — Update a note
    public func handle_update_note(db : *DbClient, note_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
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
                    var content = json_get_str(&raw parsed, "content")
                    if(content.size() == 0) {
                        var err = string("content is required")
                        send_error(res, 400u, &err)
                    } else {
                        underlayer_repository::update_note(db, note_id, &content)
                        var resp = string("{\"ok\":true}")
                        send_json_str(res, &raw resp)
                    }
                }
            }
        }
    }

    // DELETE /api/notes/:id — Delete a note
    public func handle_delete_note(db : *DbClient, note_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
        } else {
            underlayer_repository::delete_note(db, note_id)
            var resp = string("{\"ok\":true}")
            send_json_str(res, &raw resp)
        }
    }

    // GET /api/notes/concept/:conceptId — Get notes for a concept
    public func handle_get_concept_notes(db : *DbClient, concept_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
        } else {
            var notes = underlayer_repository::get_notes_for_concept(db, &learner_id, concept_id)
            var resp = string("[")
            var ri : size_t = 0
            while(ri < notes.size()) {
                if(ri > 0) { resp.append_view(",") } else { }
                var n = notes.get_ptr(ri)
                resp.append_view("{\"id\":\"")
                resp.append_string(&n.id)
                resp.append_view("\",\"concept_id\":\"")
                resp.append_string(&n.concept_id)
                resp.append_view("\",\"course_id\":\"")
                resp.append_string(&n.course_id)
                resp.append_view("\",\"content\":\"")
                resp.append_string(&n.content)
                resp.append_view("\",\"section_ref\":\"")
                resp.append_string(&n.section_ref)
                resp.append_view("\",\"created_at\":")
                var created_str = underlayer_core::int_to_string(n.created_at)
                resp.append_view(created_str.to_view())
                resp.append_view(",\"updated_at\":")
                var updated_str = underlayer_core::int_to_string(n.updated_at)
                resp.append_view(updated_str.to_view())
                resp.append_view("}")
                ri = ri + 1
            }
            resp.append_view("]")
            send_json_str(res, &raw resp)
        }
    }

    // GET /api/notes/search?q=query — Search notes
    public func handle_search_notes(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
        } else {
            var path = req.path.to_view()
            var query = string()
            // Parse q parameter from URL: /api/notes/search?q=...
            var qi : size_t = 0
            while(qi < path.size()) {
                if(path.get(qi) == '?') {
                    var pi = qi + 1
                    while(pi < path.size()) {
                        if(path.get(pi) == 'q' && pi + 1 < path.size() && path.get(pi + 1) == '=') {
                            var vi = pi + 2
                            while(vi < path.size() && path.get(vi) != '&') {
                                query.append(path.get(vi))
                                vi = vi + 1
                            }
                        } else { }
                        pi = pi + 1
                    }
                } else { }
                qi = qi + 1
            }
            if(query.size() == 0) {
                var err = string("q parameter is required")
                send_error(res, 400u, &err)
            } else {
                var notes = underlayer_repository::search_notes(db, &learner_id, &query)
                var resp = string("[")
                var ri : size_t = 0
                while(ri < notes.size()) {
                    if(ri > 0) { resp.append_view(",") } else { }
                    var n = notes.get_ptr(ri)
                    resp.append_view("{\"id\":\"")
                    resp.append_string(&n.id)
                    resp.append_view("\",\"concept_id\":\"")
                    resp.append_string(&n.concept_id)
                    resp.append_view("\",\"course_id\":\"")
                    resp.append_string(&n.course_id)
                    resp.append_view("\",\"content\":\"")
                    resp.append_string(&n.content)
                    resp.append_view("\",\"section_ref\":\"")
                    resp.append_string(&n.section_ref)
                    resp.append_view("\",\"created_at\":")
                    var created_str = underlayer_core::int_to_string(n.created_at)
                    resp.append_view(created_str.to_view())
                    resp.append_view(",\"updated_at\":")
                    var updated_str = underlayer_core::int_to_string(n.updated_at)
                    resp.append_view(updated_str.to_view())
                    resp.append_view("}")
                    ri = ri + 1
                }
                resp.append_view("]")
                send_json_str(res, &raw resp)
            }
        }
    }

}
