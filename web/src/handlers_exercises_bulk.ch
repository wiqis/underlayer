// underlayer_web — Bulk Exercise Import API handlers.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::Exercise
using underlayer_models::ExerciseType
using underlayer_repository::ExerciseStats

public namespace underlayer_web {

    // POST /api/exercises/import — Accept JSON array of exercises and bulk insert
    public func handle_exercise_import(db : *DbClient, req : &mut http::Request) : http::Response {
        var body = read_body(req)
        if(body.size() == 0) {
            var err_msg = string("empty request body")
            return send_error(400u, &err_msg)
        }

        var parsed = json::parse(body.to_view())
        if(parsed is std::Result.Err) {
            var err_msg2 = string("invalid JSON")
            return send_error(400u, &err_msg2)
        }
        var Ok(json_val) = parsed else unsafe { unreachable }

        var exercises_opt = json_get(&json_val, "exercises")
        if(exercises_opt is std::Option.None) {
            var err_msg3 = string("missing 'exercises' array")
            return send_error(400u, &err_msg3)
        }

        var Some(exercises_field) = exercises_opt else unsafe { unreachable }
        if(!(exercises_field is JsonValue.Array)) {
            var err_msg4 = string("'exercises' must be an array")
            return send_error(400u, &err_msg4)
        }
        var Array(arr) = exercises_field else unsafe { unreachable }

        var inserted_count = 0
        var error_count = 0
        var i : size_t = 0
        while(i < arr.size()) {
            var item_ptr = arr.at_ref(i)
            var ex = Exercise::make()

            ex.concept_id = json_get_str(item_ptr, "concept_id")
            ex.question = json_get_str(item_ptr, "question")
            ex.answer = json_get_str(item_ptr, "answer")
            ex.explanation = json_get_str(item_ptr, "explanation")
            ex.hint1 = json_get_str(item_ptr, "hint1")
            ex.hint2 = json_get_str(item_ptr, "hint2")
            ex.hint3 = json_get_str(item_ptr, "hint3")
            ex.correct_index = json_get_int(item_ptr, "correct_index")

            var type_str = json_get_str(item_ptr, "type")
            ex.exercise_type = underlayer_repository::exercise_type_from_str(&type_str)

            var options_str = json_get_str(item_ptr, "options")
            if(options_str.size() > 0) {
                var opt_start : size_t = 0
                var oi : size_t = 0
                while(oi <= options_str.size()) {
                    if(oi == options_str.size() || options_str.at(oi) == '|') {
                        var opt = string()
                        var oj : size_t = opt_start
                        while(oj < oi) {
                            opt.append(options_str.at(oj))
                            oj = oj + 1
                        }
                        ex.options.push(opt)
                        opt_start = oi + 1
                    }
                    oi = oi + 1
                }
            }

            if(ex.id.size() == 0) {
                var ts_str = underlayer_core::int_to_string(underlayer_core::current_timestamp())
                var idx_str = underlayer_core::int_to_string(i as i64)
                ex.id = ts_str
                ex.id.append_view("_")
                ex.id.append_view(idx_str.to_view())
            }

            if(ex.concept_id.size() > 0) {
                underlayer_repository::insert_exercise(db, &ex)
                inserted_count = inserted_count + 1
            } else {
                error_count = error_count + 1
            }
            i = i + 1
        }

        var resp = std::string("{\"inserted\":")
        var count_str = underlayer_core::int_to_string(inserted_count as i64)
        resp.append_string(&count_str)
        resp.append_view(",\"errors\":")
        var err_str = underlayer_core::int_to_string(error_count as i64)
        resp.append_string(&err_str)
        resp.append_view("}")
        return send_json_str(&resp)
    }

    // POST /api/exercises/seed — Seed exercises from course manifest data
    // (P1 4.1.27: logic moved to underlayer_repository::seed_exercises_from_manifest
    //  so the same function runs at server startup and via this manual endpoint.)
    public func handle_exercise_seed(db : *DbClient, req : &mut http::Request) : http::Response {
        var courses_dir = string("./courses")
        var env_dir = underlayer_core::get_env_str("COURSES_DIR")
        if(env_dir.size() > 0) { courses_dir = env_dir }

        var course_id = string("elf")
        var inserted_count = underlayer_repository::seed_exercises_from_manifest(db, &courses_dir, &course_id)

        var resp = std::string("{\"inserted\":")
        var count_str = underlayer_core::int_to_string(inserted_count as i64)
        resp.append_string(&count_str)
        resp.append_view("}")
        return send_json_str(&resp)
    }

    // GET /api/exercises/stats — Get exercise count per concept
    public func handle_exercise_stats(db : *DbClient, req : &http::Request) : http::Response {
        var stats = underlayer_repository::get_exercise_stats(db)

        var resp = std::string("{\"stats\":[")
        var i : size_t = 0
        while(i < stats.size()) {
            if(i > 0) { resp.append_view(",") }
            var stat = stats.at_ref(i)
            resp.append_view("{\"concept_id\":\"")
            resp.append_string(&stat.concept_id)
            resp.append_view("\",\"exercise_count\":")
            var count_str = underlayer_core::int_to_string(stat.exercise_count as i64)
            resp.append_string(&count_str)
            resp.append_view(",\"avg_difficulty\":")
            var diff_str = underlayer_learning::f64_to_string(stat.avg_difficulty as f64)
            resp.append_string(&diff_str)
            resp.append_view("}")
            i = i + 1
        }
        resp.append_view("],\"total\":")
        var total_str = underlayer_core::int_to_string(stats.size() as i64)
        resp.append_string(&total_str)
        resp.append_view("}")
        return send_json_str(&resp)
    }

}
