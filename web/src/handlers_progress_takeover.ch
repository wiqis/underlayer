// G13 — safe guest → account progress takeover.
//
// POST /api/progress/takeover/token   anonymous; mints a one-shot token
// POST /api/progress/takeover         bearer/cookie required; replays guest
//                                    changes through the SAME per-key
//                                    updated_at rule as /api/progress/sync.
//
// NOTHING here writes stability, reps, interval, next_review, attempts,
// correct or streak. Those are FSRS-authoritative and owned by
// /api/review/submit alone. The token is consumed BEFORE any replay, and a
// replay of the same token is refused with 409 and writes nothing.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::UnitProgress

public namespace underlayer_web {

    public func handle_takeover_token(db : *DbClient, req : &http::Request) : http::Response {
        var token = underlayer_repository::takeover_token_create(db)
        if(token.size() == 0) {
            var err = string("could not mint a takeover token")
            return send_error(500u, &err)
        }
        var esc = underlayer_core::json_escape(&token.to_view())
        var body = string("{\"token\":\"")
        body.append_string(&esc)
        body.append_view("\",\"expires_in\":3600}")
        return send_json_str(&body)
    }

    public func handle_progress_takeover(db : *DbClient, req : &mut http::Request) : http::Response {
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
        var token = json_get_str(&parsed, "token")
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
        // Consume FIRST. A token that cannot be claimed never reaches a write,
        // so a replay is a no-op by construction rather than by convention.
        if(!underlayer_repository::takeover_token_consume(db, &token, &learner_id)) {
            var used = string("takeover token invalid, expired or already used")
            return send_error(409u, &used)
        }

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
                var idx = underlayer_core::int_to_string(i as i64)
                bad_at.append_string(&idx)
                return send_error(400u, &bad_at)
            }
            // The exact repository function /api/progress/sync uses. Same key,
            // same strictly-newer rule, same refusal of equal timestamps.
            underlayer_repository::progress_sync_apply(db, &change)
            var stored = underlayer_repository::progress_sync_get(
                db, &change.learner_id, &change.course_id,
                &change.concept_id, &change.unit_id)
            effective.push(stored)
            i = i + 1
        }

        var body = string("{\"applied\":true,\"server_now\":")
        var now = underlayer_core::current_timestamp()
        var now_s = underlayer_core::int_to_string(now)
        body.append_string(&now_s)
        body.append_view(",\"changes\":")
        append_changes_json(&mut body, &effective)
        // Read-only FSRS projection, identical to the sync contract. It cannot
        // alter a schedule; it exists so a client can see the untouched state.
        append_fsrs_json(db, &mut body, &effective)
        body.append_view("}")
        return send_json_str(&body)
    }

}
