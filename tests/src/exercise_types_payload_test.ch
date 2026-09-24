// 4.1.29 — Exercise UI API tests for all 8 lesson types.
// GET payload fields (type, right_options, blank_count) + submit grading.
using std::string
using std::string_view
using std::Result
using std::Option
using underlayer_models::Exercise

@test
public func test_exercise_get_all_types_payload(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db_path(&string("./test_ex_payload.db"))

    var ex_multi = Exercise::make()
    ex_multi.id = string("t_multi")
    ex_multi.concept_id = string("t-concept-multi")
    ex_multi.exercise_type = underlayer_repository::exercise_type_from_str(&string("multi_recognize"))
    ex_multi.question = string("Pick both")
    ex_multi.options.push(string("A"))
    ex_multi.options.push(string("B"))
    ex_multi.correct_indices.push(0)
    ex_multi.correct_indices.push(1)
    underlayer_repository::insert_exercise(&raw db, &raw ex_multi)

    var ex_match = Exercise::make()
    ex_match.id = string("t_match")
    ex_match.concept_id = string("t-concept-match")
    ex_match.exercise_type = underlayer_models::exercise_type_matching()
    ex_match.question = string("Match pairs")
    ex_match.options.push(string("Left1"))
    ex_match.options.push(string("Left2"))
    ex_match.answer = string("RightA|RightB")
    underlayer_repository::insert_exercise(&raw db, &raw ex_match)

    var ex_label = Exercise::make()
    ex_label.id = string("t_label")
    ex_label.concept_id = string("t-concept-label")
    ex_label.exercise_type = underlayer_models::exercise_type_labeling()
    ex_label.question = string("Label three parts")
    ex_label.answer = string("One|Two|Three")
    underlayer_repository::insert_exercise(&raw db, &raw ex_label)

    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20126")
    var srv = server.Server(cfg)
    srv.router.add("GET", "/api/exercises/:conceptId", (|&db|(req, res) => {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        if(segments.size() >= 3) {
            var concept_id = segments.get_ptr(2)
            underlayer_web::handle_get_exercises(db, concept_id, &req, &raw mut res)
        } else {
            res.status = 400u
        }
    }))
    srv.serve_async(20126u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()

    var res1 = client.get("http://127.0.0.1:20126/api/exercises/t-concept-multi")
    if(res1 is Result.Err) { env.error("multi request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp1) = res1 else unreachable
    if(resp1.status != 200u) { env.error("multi expected 200") }
    var body1_opt = resp1.body.read_to_string()
    if(body1_opt is Option.None) { env.error("multi no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body1) = body1_opt else unreachable
    if(body1.find(string_view("\"type\":\"multi_recognize\"")) == std::NPOS) {
        env.error("multi missing type multi_recognize")
    }

    var res2 = client.get("http://127.0.0.1:20126/api/exercises/t-concept-match")
    if(res2 is Result.Err) { env.error("match request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp2) = res2 else unreachable
    var body2_opt = resp2.body.read_to_string()
    if(body2_opt is Option.None) { env.error("match no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body2) = body2_opt else unreachable
    if(body2.find(string_view("\"type\":\"matching\"")) == std::NPOS) {
        env.error("match missing type matching")
    }
    if(body2.find(string_view("right_options")) == std::NPOS) {
        env.error("match missing right_options")
    }
    // Rights are reversed on the wire so right_options[0] != correct pair for left[0]
    if(body2.find(string_view("\"right_options\":[\"RightB\",\"RightA\"]")) == std::NPOS) {
        env.error("match right_options not reversed")
    }

    var res3 = client.get("http://127.0.0.1:20126/api/exercises/t-concept-label")
    if(res3 is Result.Err) { env.error("label request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(resp3) = res3 else unreachable
    var body3_opt = resp3.body.read_to_string()
    if(body3_opt is Option.None) { env.error("label no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(body3) = body3_opt else unreachable
    if(body3.find(string_view("blank_count")) == std::NPOS) {
        env.error("label missing blank_count")
    }
    if(body3.find(string_view("\"blank_count\":3")) == std::NPOS) {
        env.error("label blank_count should be 3")
    }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

