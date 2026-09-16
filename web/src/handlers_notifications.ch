// underlayer_web — Notification API handlers.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // GET /api/notifications — Get notifications for current user
    public func handle_get_notifications(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var notifs = underlayer_repository::get_notifications(db, &learner_id, 50)
        var resp = string("[")
        var i : size_t = 0
        while(i < notifs.size()) {
            if(i > 0) { resp.append_view(",") }
            var n = notifs.get_ptr(i)
            resp.append_view("{\"id\":\"")
            resp.append_string(&n.id)
            resp.append_view("\",\"type\":\"")
            resp.append_string(&n.type)
            resp.append_view("\",\"title\":\"")
            resp.append_string(&n.title)
            resp.append_view("\",\"message\":\"")
            resp.append_string(&n.message)
            resp.append_view("\",\"course_id\":\"")
            resp.append_string(&n.course_id)
            resp.append_view("\",\"concept_id\":\"")
            resp.append_string(&n.concept_id)
            resp.append_view("\",\"is_read\":")
            if(n.is_read) { resp.append_view("true") } else { resp.append_view("false") }
            resp.append_view(",\"action_url\":\"")
            resp.append_string(&n.action_url)
            resp.append_view("\",\"created_at\":")
            var ts_str = underlayer_core::int_to_string(n.created_at)
            resp.append_view(ts_str.to_view())
            resp.append_view("}")
            i = i + 1
        }
        resp.append_view("]")
        send_json_str(res, &raw resp)
    }

    // GET /api/notifications/unread-count — Get unread count
    public func handle_unread_count(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var count = underlayer_repository::get_unread_count(db, &learner_id)
        var resp = string("{\"count\":")
        var count_str = underlayer_core::int_to_string(count)
        resp.append_view(count_str.to_view())
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

    // POST /api/notifications/:id/read — Mark one as read
    public func handle_mark_read(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() < 4) {
            var err = string("missing notification id")
            send_error(res, 400u, &err)
            return
        }
        var notif_id = segments.get_ptr(3).to_string()
        underlayer_repository::mark_read(db, &notif_id)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // POST /api/notifications/read-all — Mark all as read
    public func handle_mark_all_read(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        underlayer_repository::mark_all_read(db, &learner_id)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

    // DELETE /api/notifications/:id — Delete a notification
    public func handle_delete_notification(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var err = string("unauthorized")
            send_error(res, 401u, &err)
            return
        }
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() < 4) {
            var err = string("missing notification id")
            send_error(res, 400u, &err)
            return
        }
        var notif_id = segments.get_ptr(3).to_string()
        underlayer_repository::delete_notification(db, &notif_id)
        var resp = string("{\"ok\":true}")
        send_json_str(res, &raw resp)
    }

}