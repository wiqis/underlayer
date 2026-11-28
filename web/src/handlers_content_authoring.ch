// underlayer_web — operator-gated course content writes (H9).
//
// WHAT WAS OPEN. POST /api/exercises/import let an anonymous caller rewrite the
// global graded bank, including answer keys. It was refused in the security
// pass because no author identity existed. H9 supplies one WITHOUT a role
// column on `learners`: the server resolves the session to a stable identity
// and checks the secret-store UL_OPERATOR_IDS list (constant-time), then
// audits the action. A client-supplied `operator`/`role` field is never read.
//
// The routes stay registered. With no allow-list configured the behaviour is
// byte-for-byte the old refusal (401 anonymous, 403 signed-in), so every
// shipped gate that asserts those statuses keeps passing.
using std::string
using std::string_view
using underlayer_db::DbClient
using underlayer_models::Exercise

public namespace underlayer_web {

    private func content_audit_details(path : &string, count : int) : string {
        var details = path.copy()
        details.append_view(" items=")
        var n = underlayer_core::int_to_string(count as i64)
        details.append_view(n.to_view())
        return details
    }

    // POST /api/exercises/import — insert a caller-supplied bank. Operator only.
    public func refuse_exercise_import(db : *DbClient, req : &http::Request) : http::Response {
        var path = string("POST /api/exercises/import")
        var gate = require_operator(db, req, string("content.exercises.import"), &path)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return refusal
        }
        var body = read_body(req)
        if(body.empty()) {
            var err = string("empty request body")
            return send_error(400u, &err)
        }
        var parsed_result = json::parse(body.to_view())
        if(parsed_result is std::Result.Err) {
            var err = string("invalid JSON")
            return send_error(400u, &err)
        }
        var Ok(root) = parsed_result else unsafe { unreachable }
        var node = json_get(&root, "exercises")
        if(node is std::Option.None) {
            var err = string("missing 'exercises' array")
            return send_error(400u, &err)
        }
        var Some(arr_node) = node else unsafe { unreachable }
        if(!(arr_node is JsonValue.Array)) {
            var err = string("'exercises' must be an array")
            return send_error(400u, &err)
        }
        var Array(arr) = arr_node else unsafe { unreachable }

        var inserted = 0
        var errors = 0
        var i : size_t = 0
        while(i < arr.size()) {
            var item = arr.at_ref(i)
            var ex = Exercise::make()
            ex.concept_id = json_get_str(item, "concept_id")
            ex.question = json_get_str(item, "question")
            ex.answer = json_get_str(item, "answer")
            ex.explanation = json_get_str(item, "explanation")
            ex.hint1 = json_get_str(item, "hint1")
            ex.hint2 = json_get_str(item, "hint2")
            ex.hint3 = json_get_str(item, "hint3")
            ex.correct_index = json_get_int(item, "correct_index")
            var type_str = json_get_str(item, "type")
            ex.exercise_type = underlayer_repository::exercise_type_from_str(&type_str)
            var options_str = json_get_str(item, "options")
            var start : size_t = 0
            var oi : size_t = 0
            while(oi <= options_str.size()) {
                if(oi == options_str.size() || options_str.at(oi) == '|') {
                    var opt = string()
                    var oj = start
                    while(oj < oi) { opt.append(options_str.at(oj)); oj = oj + 1 }
                    ex.options.push(opt)
                    start = oi + 1
                }
                oi = oi + 1
            }
            if(ex.concept_id.size() > 0) {
                var ts = underlayer_core::int_to_string(underlayer_core::current_timestamp())
                var idx = underlayer_core::int_to_string(i as i64)
                ex.id = ts
                ex.id.append_view("_")
                ex.id.append_view(idx.to_view())
                underlayer_repository::insert_exercise(db, &ex)
                inserted = inserted + 1
            } else {
                errors = errors + 1
            }
            i = i + 1
        }

        var details = content_audit_details(&path, inserted)
        var rid = operator_request_id(req)
        var caller = auth_get_learner_id(db, req)
        var actor = underlayer_repository::operator_identity(db, &caller)
        var peer = req.remote.copy()
        underlayer_repository::write_operator_audit(db, &actor, &rid, &peer, string("content.exercises.import.wrote"), &details)

        var resp = string("{\"inserted\":")
        var ins = underlayer_core::int_to_string(inserted as i64)
        resp.append_view(ins.to_view())
        resp.append_view(",\"errors\":")
        var errs = underlayer_core::int_to_string(errors as i64)
        resp.append_view(errs.to_view())
        resp.append_view("}")
        return send_json_str(&resp)
    }

    // POST /api/exercises/seed — repopulate the bank from a manifest. Operator only.
    public func refuse_exercise_seed(db : *DbClient, req : &http::Request) : http::Response {
        var path = string("POST /api/exercises/seed")
        var gate = require_operator(db, req, string("content.exercises.seed"), &path)
        if(gate is std::Option.Some) {
            var Some(refusal) = gate else unsafe { unreachable }
            return refusal
        }
        var courses_dir = underlayer_core::get_env_str("COURSES_DIR")
        if(courses_dir.empty()) { courses_dir = string("./courses") }
        var course_id = string("elf")
        var inserted = underlayer_repository::seed_exercises_from_manifest(db, &courses_dir, &course_id)
        var details = content_audit_details(&path, inserted)
        details.append_view(" course=elf")
        var rid = operator_request_id(req)
        var caller = auth_get_learner_id(db, req)
        var actor = underlayer_repository::operator_identity(db, &caller)
        var peer = req.remote.copy()
        underlayer_repository::write_operator_audit(db, &actor, &rid, &peer, string("content.exercises.seed.wrote"), &details)
        var resp = string("{\"inserted\":")
        var ins = underlayer_core::int_to_string(inserted as i64)
        resp.append_view(ins.to_view())
        resp.append_view("}")
        return send_json_str(&resp)
    }

}
