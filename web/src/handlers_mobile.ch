// underlayer_web — S-2/S-3: timestamped progress sync for the Android client.
//
// POST /api/progress/sync   bearer required, last-write-wins push
// GET  /api/progress/sync?since=<unix seconds>   bearer required, delta pull
//
// Both answers are {server_now, changes:[...], fsrs:[...]}.  FSRS fields are
// READ from review_items and are never written by either route.  The client
// sends only status / step_index / updated_at per unit.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::UnitProgress

public namespace underlayer_web {

    public func handle_progress_sync_push(db : *DbClient, req : &mut http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var unauthorized = string("unauthorized")
            return send_error(401u, &unauthorized)
        }
        var raw = read_body(req)
        if(raw.size() == 0) {
            var empty = string("missing request body")
            return send_error(400u, &empty)
        }
        var parsed_result = json::parse(raw.to_view())
        if(parsed_result is std::Result.Err) {
            var bad_json = string("invalid JSON")
            return send_error(400u, &bad_json)
        }
        var Ok(parsed) = parsed_result else unsafe { unreachable }
        if(!(parsed is JsonValue.Object)) {
            var not_object = string("expected a JSON object")
            return send_error(400u, &not_object)
        }
        var now_node = json_get(&parsed, "client_now")
        if(now_node is std::Option.None) {
            var missing_now = string("client_now is required")
            return send_error(400u, &missing_now)
        }
        var Some(now_val) = now_node else unsafe { unreachable }
        if(!(now_val is JsonValue.Number)) {
            var bad_now = string("client_now must be a number")
            return send_error(400u, &bad_now)
        }
        var changes_node = json_get(&parsed, "changes")
        if(changes_node is std::Option.None) {
            var missing_changes = string("changes is required")
            return send_error(400u, &missing_changes)
        }
        var Some(changes_val) = changes_node else unsafe { unreachable }
        if(!(changes_val is JsonValue.Array)) {
            var bad_changes = string("changes must be an array")
            return send_error(400u, &bad_changes)
        }

        // Apply each change, then read back what the server actually holds.
        // A rejected (older) write therefore comes back with the newer stored
        // timestamp and status, which is what the client needs to converge.
        var effective = vector<UnitProgress>()
        var i : size_t = 0
        while(i < underlayer_repository::json_len(changes_val)) {
            var maybe = underlayer_repository::json_at(changes_val, i)
            if(maybe is std::Option.None) {
                var bad_item = string("invalid change")
                return send_error(400u, &bad_item)
            }
            var Some(item) = maybe else unsafe { unreachable }
            var change = UnitProgress::make()
            change.learner_id = learner_id.copy()
            if(!parse_unit_change(item, &mut change)) {
                var bad_at = string("invalid change at index ")
                var idx_str = underlayer_core::int_to_string(i as i64)
                bad_at.append_string(&idx_str)
                return send_error(400u, &bad_at)
            }
            underlayer_repository::progress_sync_apply(db, &change)
            var stored = underlayer_repository::progress_sync_get(
                db,
                &change.learner_id,
                &change.course_id,
                &change.concept_id,
                &change.unit_id
            )
            effective.push(stored)
            i = i + 1
        }

        var body = string("{\"server_now\":")
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        body.append_string(&now_str)
        body.append_view(",\"changes\":")
        append_changes_json(&mut body, &effective)
        append_fsrs_json(db, &mut body, &effective)
        body.append_view("}")
        return send_json_str(&body)
    }

    public func handle_progress_sync_pull(db : *DbClient, req : &http::Request) : http::Response {
        var learner_id = auth_get_learner_id(db, req)
        if(learner_id.size() == 0) {
            var unauthorized = string("unauthorized")
            return send_error(401u, &unauthorized)
        }
        var key = string("since")
        var since_view = sv_or_empty(req.query.get(std::str.make_view(key.to_view())))
        if(!valid_since(&since_view)) {
            var bad_since = string("since must be a unix timestamp")
            return send_error(400u, &bad_since)
        }
        var since = underlayer_repository::parse_i64(since_view)
        var changes = underlayer_repository::progress_sync_since(db, &learner_id, since)
        var body = string("{\"server_now\":")
        var now = underlayer_core::current_timestamp()
        var now_str = underlayer_core::int_to_string(now)
        body.append_string(&now_str)
        body.append_view(",\"changes\":")
        append_changes_json(&mut body, &changes)
        append_fsrs_json(db, &mut body, &changes)
        body.append_view("}")
        return send_json_str(&body)
    }

    private func valid_since(v : &string_view) : bool {
        if(v.size() == 0) { return false }
        var i : size_t = 0
        while(i < v.size()) {
            var c = v.at(i)
            if(c < '0' || c > '9') { return false }
            i = i + 1
        }
        return true
    }

}
