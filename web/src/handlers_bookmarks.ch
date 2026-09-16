// underlayer_web — Bookmark API handlers.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // POST /api/bookmarks — Add a bookmark
    public func handle_add_bookmark(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
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
        var note = json_get_str(&raw parsed, "note")
        if(concept_id.size() == 0) {
            var err = string("concept_id is required")
            send_error(res, 400u, &err)
            return
        }
        if(course_id.size() == 0) {
            var err = string("course_id is required")
            send_error(res, 400u, &err)
            return
        }
        var bookmark_id = underlayer_repository::add_bookmark(db, &learner_id, &concept_id, &course_id, &note)
        var resp = string("{\"ok\":true,\"id\":\"")
        resp.append_string(&bookmark_id)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // DELETE /api/bookmarks/:conceptId — Remove a bookmark
    public func handle_remove_bookmark(db : *DbClient, concept_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        underlayer_repository::remove_bookmark(db, &learner_id, concept_id)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // GET /api/bookmarks — List all bookmarks for current user
    public func handle_get_bookmarks(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var bookmarks = underlayer_repository::get_bookmarks(db, &learner_id)
        var resp = string("[")
        var ri : size_t = 0
        while(ri < bookmarks.size()) {
            if(ri > 0) { resp.append_view(",") }
            var bm = bookmarks.get_ptr(ri)
            resp.append_view("{\"id\":\"")
            resp.append_string(&bm.id)
            resp.append_view("\",\"learner_id\":\"")
            resp.append_string(&bm.learner_id)
            resp.append_view("\",\"concept_id\":\"")
            resp.append_string(&bm.concept_id)
            resp.append_view("\",\"course_id\":\"")
            resp.append_string(&bm.course_id)
            resp.append_view("\",\"note\":\"")
            resp.append_string(&bm.note)
            resp.append_view("\",\"created_at\":")
            var ts_str = underlayer_core::int_to_string(bm.created_at)
            resp.append_view(ts_str.to_view())
            resp.append_view("}")
            ri = ri + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

    // GET /api/bookmarks/check/:conceptId — Check if concept is bookmarked
    public func handle_check_bookmark(db : *DbClient, concept_id : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var bookmarked = underlayer_repository::is_bookmarked(db, &learner_id, concept_id)
        var resp = string("{\"bookmarked\":")
        if(bookmarked) { resp.append_view("true") } else { resp.append_view("false") }
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

}
