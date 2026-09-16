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
    public func handle_exercise_import(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var body = read_body(req)
        if(body.size() == 0) {
            send_error(res, 400u, &string("empty request body"))
            return
        }

        var parsed = json::parse(body.to_view())
        if(parsed is std::Result.Err) {
            send_error(res, 400u, &string("invalid JSON"))
            return
        }
        var Ok(json_val) = parsed else unreachable

        var exercises_field = json_get(&raw json_val, "exercises")
        if(exercises_field == null) {
            send_error(res, 400u, &string("missing 'exercises' array"))
            return
        }

        if(!(exercises_field is JsonValue.Array)) {
            send_error(res, 400u, &string("'exercises' must be an array"))
            return
        }
        var Array(arr) = *exercises_field else unreachable

        var inserted_count = 0
        var error_count = 0
        var i : size_t = 0
        while(i < arr.size()) {
            var item_ptr = arr.get_ptr(i)
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
            if(type_str.equals(string("multiple_choice"))) {
                ex.exercise_type = underlayer_models::exercise_type_recognize()
            } else if(type_str.equals(string("multi_recognize"))) {
                ex.exercise_type = underlayer_models::exercise_type_multi_recognize()
            } else if(type_str.equals(string("free_recall"))) {
                ex.exercise_type = underlayer_models::exercise_type_recall()
            } else if(type_str.equals(string("cued_recall"))) {
                ex.exercise_type = underlayer_models::exercise_type_apply()
            } else {
                ex.exercise_type = underlayer_models::exercise_type_recognize()
            }

            var options_str = json_get_str(item_ptr, "options")
            if(options_str.size() > 0) {
                var opt_start : size_t = 0
                var oi : size_t = 0
                while(oi <= options_str.size()) {
                    if(oi == options_str.size() || options_str.get(oi) == '|') {
                        var opt = string()
                        var oj : size_t = opt_start
                        while(oj < oi) {
                            opt.append(options_str.get(oj))
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
                underlayer_repository::insert_exercise(&raw db, &raw ex)
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
        send_json_str(res, &raw resp)
    }

    // POST /api/exercises/seed — Seed exercises from course manifest data
    public func handle_exercise_seed(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var courses_dir = string("./courses")

        var courses = vector<string>()
        courses.push(string("elf"))

        var inserted_count = 0
        var ci : size_t = 0
        while(ci < courses.size()) {
            var course_id = courses.get_ptr(ci).copy()
            var manifest_path = courses_dir.copy()
            manifest_path.append_view("/")
            manifest_path.append_view(course_id.to_view())
            manifest_path.append_view("/manifest.json")

            var manifest_result = fs::read_entire_file(manifest_path.data())
            if(manifest_result is std::Result.Err) {
                ci = ci + 1
                continue
            }
            var Ok(manifest_data) = manifest_result else unreachable
            var manifest_content = string()
            var di2 : size_t = 0
            while(di2 < manifest_data.size()) {
                manifest_content.append(manifest_data.get(di2) as char)
                di2 = di2 + 1
            }
            if(manifest_content.size() == 0) {
                ci = ci + 1
                continue
            }

            var manifest_json = json::parse(manifest_content.to_view())
            if(manifest_json is std::Result.Err) {
                ci = ci + 1
                continue
            }
            var Ok(manifest_val) = manifest_json else unreachable

            var exercise_decls = json_get(&raw manifest_val, "exercise_decls")
            if(exercise_decls != null && exercise_decls is JsonValue.Array) {
                var Array(decls) = *exercise_decls else unreachable
                var di : size_t = 0
                while(di < decls.size()) {
                    var decl_ptr = decls.get_ptr(di)
                    var ex = Exercise::make()
                    ex.concept_id = json_get_str(decl_ptr, "concept_id")
                    ex.question = json_get_str(decl_ptr, "question")
                    ex.answer = json_get_str(decl_ptr, "answer")
                    ex.explanation = json_get_str(decl_ptr, "explanation")
                    ex.hint1 = json_get_str(decl_ptr, "hint1")
                    ex.hint2 = json_get_str(decl_ptr, "hint2")
                    ex.hint3 = json_get_str(decl_ptr, "hint3")
                    ex.correct_index = json_get_int(decl_ptr, "correct_index")

                    var type_str = json_get_str(decl_ptr, "type")
                    if(type_str.equals(string("multiple_choice"))) {
                        ex.exercise_type = underlayer_models::exercise_type_recognize()
                    } else if(type_str.equals(string("multi_recognize"))) {
                        ex.exercise_type = underlayer_models::exercise_type_multi_recognize()
                    } else if(type_str.equals(string("free_recall"))) {
                        ex.exercise_type = underlayer_models::exercise_type_recall()
                    } else if(type_str.equals(string("cued_recall"))) {
                        ex.exercise_type = underlayer_models::exercise_type_apply()
                    } else {
                        ex.exercise_type = underlayer_models::exercise_type_recognize()
                    }

                    var options_str = json_get_str(decl_ptr, "options")
                    if(options_str.size() > 0) {
                        var opt_start : size_t = 0
                        var oi : size_t = 0
                        while(oi <= options_str.size()) {
                            if(oi == options_str.size() || options_str.get(oi) == '|') {
                                var opt = string()
                                var oj : size_t = opt_start
                                while(oj < oi) {
                                    opt.append(options_str.get(oj))
                                    oj = oj + 1
                                }
                                ex.options.push(opt)
                                opt_start = oi + 1
                            }
                            oi = oi + 1
                        }
                    }

                    var id_str = course_id.copy()
                    id_str.append_view("_")
                    id_str.append_view(ex.concept_id.to_view())
                    id_str.append_view("_")
                    var di_str = underlayer_core::int_to_string(di as i64)
                    id_str.append_view(di_str.to_view())
                    ex.id = id_str

                    if(ex.concept_id.size() > 0) {
                        underlayer_repository::insert_exercise(&raw db, &raw ex)
                        inserted_count = inserted_count + 1
                    }
                    di = di + 1
                }
            }
            ci = ci + 1
        }

        var resp = std::string("{\"inserted\":")
        var count_str = underlayer_core::int_to_string(inserted_count as i64)
        resp.append_string(&count_str)
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

    // GET /api/exercises/stats — Get exercise count per concept
    public func handle_exercise_stats(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var stats = underlayer_repository::get_exercise_stats(&raw db)

        var resp = std::string("{\"stats\":[")
        var i : size_t = 0
        while(i < stats.size()) {
            if(i > 0) { resp.append_view(",") }
            var stat = stats.get_ptr(i)
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
        send_json_str(res, &raw resp)
    }

}