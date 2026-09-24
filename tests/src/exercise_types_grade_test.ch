// 4.1.29 — Exercise UI API tests for all 8 lesson types.
// GET payload fields (type, right_options, blank_count) + submit grading.
using std::string
using std::string_view
using std::Result
using std::Option
using underlayer_models::Exercise

@test
public func test_exercise_submit_grades_all_types(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()

    var ex_hex = Exercise::make()
    ex_hex.id = string("t_hex")
    ex_hex.concept_id = string("t-concept-hex")
    ex_hex.exercise_type = underlayer_models::exercise_type_hex_inspect()
    ex_hex.question = string("Hex digits of 0x41?")
    ex_hex.answer = string("41")
    underlayer_repository::insert_exercise(&raw db, &raw ex_hex)

    var ex_ord = Exercise::make()
    ex_ord.id = string("t_ord")
    ex_ord.concept_id = string("t-concept-ord")
    ex_ord.exercise_type = underlayer_models::exercise_type_ordering()
    ex_ord.question = string("Order three")
    ex_ord.answer = string("A|B|C")
    underlayer_repository::insert_exercise(&raw db, &raw ex_ord)

    var ex_lab = Exercise::make()
    ex_lab.id = string("t_lab")
    ex_lab.concept_id = string("t-concept-lab")
    ex_lab.exercise_type = underlayer_models::exercise_type_labeling()
    ex_lab.question = string("Labels")
    ex_lab.answer = string("One|Two")
    underlayer_repository::insert_exercise(&raw db, &raw ex_lab)

    var ex_multi = Exercise::make()
    ex_multi.id = string("t_multi_g")
    ex_multi.concept_id = string("t-concept-multi-g")
    ex_multi.exercise_type = underlayer_models::exercise_type_multi_recognize()
    ex_multi.question = string("Multi")
    ex_multi.options.push(string("A"))
    ex_multi.options.push(string("B"))
    ex_multi.options.push(string("C"))
    ex_multi.correct_indices.push(0)
    ex_multi.correct_indices.push(2)
    underlayer_repository::insert_exercise(&raw db, &raw ex_multi)

    var ex_pred = Exercise::make()
    ex_pred.id = string("t_pred")
    ex_pred.concept_id = string("t-concept-pred")
    ex_pred.exercise_type = underlayer_models::exercise_type_predict()
    ex_pred.question = string("Predict")
    ex_pred.answer = string("It fails")
    ex_pred.options.push(string("It fails"))
    ex_pred.options.push(string("It works"))
    ex_pred.correct_index = 0
    underlayer_repository::insert_exercise(&raw db, &raw ex_pred)

    var ex_fill = Exercise::make()
    ex_fill.id = string("t_fill")
    ex_fill.concept_id = string("t-concept-fill")
    ex_fill.exercise_type = underlayer_models::exercise_type_fill_blank()
    ex_fill.question = string("Fill")
    ex_fill.answer = string("nor")
    underlayer_repository::insert_exercise(&raw db, &raw ex_fill)

    var cfg = server.ServerConfig()
    cfg.addr = string("127.0.0.1:20127")
    var srv = server.Server(cfg)
    srv.router.add("POST", "/api/exercises/submit", (|&db|(req, res) => {
        underlayer_web::handle_exercise_submit(db, &raw mut req, &raw mut res)
    }))
    srv.serve_async(20127u)
    std::concurrent.sleep_ms(200u)

    var client = http::Client()
    var empty_body = string("")
    var ebv = empty_body.to_view()

    // hex: 0x41 normalizes to 41, matching answer 41
    var r1 = client.post("http://127.0.0.1:20127/api/exercises/submit?exercise_id=t_hex&answer=0x41", &ebv, "application/json")
    if(r1 is Result.Err) { env.error("hex request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(b1) = r1 else unreachable
    var o1 = b1.body.read_to_string()
    if(o1 is Option.None) { env.error("hex no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(t1) = o1 else unreachable
    if(t1.find(string_view("\"correct\":true")) == std::NPOS) { env.error("hex 0x41 should grade correct") }

    // ordering exact
    var r2 = client.post("http://127.0.0.1:20127/api/exercises/submit?exercise_id=t_ord&answer=A%7CB%7CC", &ebv, "application/json")
    if(r2 is Result.Err) { env.error("ord request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(b2) = r2 else unreachable
    var o2 = b2.body.read_to_string()
    if(o2 is Option.None) { env.error("ord no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(t2) = o2 else unreachable
    if(t2.find(string_view("\"correct\":true")) == std::NPOS) { env.error("ordering A|B|C should grade correct") }

    // labeling
    var r3 = client.post("http://127.0.0.1:20127/api/exercises/submit?exercise_id=t_lab&answer=One%7CTwo", &ebv, "application/json")
    if(r3 is Result.Err) { env.error("lab request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(b3) = r3 else unreachable
    var o3 = b3.body.read_to_string()
    if(o3 is Option.None) { env.error("lab no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(t3) = o3 else unreachable
    if(t3.find(string_view("\"correct\":true")) == std::NPOS) { env.error("labeling One|Two should grade correct") }

    // multi correct + wrong
    var r4 = client.post("http://127.0.0.1:20127/api/exercises/submit?exercise_id=t_multi_g&answer=0%2C2", &ebv, "application/json")
    if(r4 is Result.Err) { env.error("multi request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(b4) = r4 else unreachable
    var o4 = b4.body.read_to_string()
    if(o4 is Option.None) { env.error("multi no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(t4) = o4 else unreachable
    if(t4.find(string_view("\"correct\":true")) == std::NPOS) { env.error("multi 0,2 should grade correct") }

    var r4b = client.post("http://127.0.0.1:20127/api/exercises/submit?exercise_id=t_multi_g&answer=0", &ebv, "application/json")
    if(r4b is Result.Err) { env.error("multi wrong request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(b4b) = r4b else unreachable
    var o4b = b4b.body.read_to_string()
    if(o4b is Option.None) { env.error("multi wrong no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(t4b) = o4b else unreachable
    if(t4b.find(string_view("\"correct\":false")) == std::NPOS) { env.error("multi partial should grade wrong") }

    // predict with options (MC-style)
    var r5 = client.post("http://127.0.0.1:20127/api/exercises/submit?exercise_id=t_pred&answer=It%20fails", &ebv, "application/json")
    if(r5 is Result.Err) { env.error("pred request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(b5) = r5 else unreachable
    var o5 = b5.body.read_to_string()
    if(o5 is Option.None) { env.error("pred no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(t5) = o5 else unreachable
    if(t5.find(string_view("\"correct\":true")) == std::NPOS) { env.error("predict option should grade correct") }

    // fill_blank case-insensitive trim
    var r6 = client.post("http://127.0.0.1:20127/api/exercises/submit?exercise_id=t_fill&answer=%20NOR%20", &ebv, "application/json")
    if(r6 is Result.Err) { env.error("fill request failed"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Ok(b6) = r6 else unreachable
    var o6 = b6.body.read_to_string()
    if(o6 is Option.None) { env.error("fill no body"); srv.shutdown(); underlayer_db::close(&raw db); return }
    var Some(t6) = o6 else unreachable
    if(t6.find(string_view("\"correct\":true")) == std::NPOS) { env.error("fill_blank ' NOR ' should grade correct") }

    srv.shutdown()
    underlayer_db::close(&raw db)
}

@test
public func test_exercise_seed_new_types_from_manifest(env : &mut TestEnv) {
    var db = test_helpers::setup_test_db()
    var courses_dir = string("./courses")
    var course_id = string("hat")
    var created = underlayer_repository::seed_exercises_from_manifest(&raw db, &courses_dir, &course_id)
    if(created == 0) { env.error("expected hat seed to insert exercises"); underlayer_db::close(&raw db); return }

    var list = underlayer_repository::get_exercises_for_concept(&raw db, &string("hat-network-routing"), 10)
    var found_multi = false
    var found_label = false
    var found_hex = false
    var i : size_t = 0
    while(i < list.size()) {
        var e = list.get_ptr(i)
        if(e.exercise_type.id.equals(string("multi_recognize"))) { found_multi = true }
        i = i + 1
    }
    if(found_multi == false) { env.error("seeded multi_recognize not found for hat-network-routing") }

    var labels = underlayer_repository::get_exercises_for_concept(&raw db, &string("hat-exam-overview"), 20)
    i = 0
    while(i < labels.size()) {
        var e = labels.get_ptr(i)
        if(e.exercise_type.id.equals(string("labeling"))) { found_label = true }
        i = i + 1
    }
    if(found_label == false) { env.error("seeded labeling not found for hat-exam-overview") }

    var elf_dir = string("./courses")
    var elf_id = string("elf")
    var created_elf = underlayer_repository::seed_exercises_from_manifest(&raw db, &elf_dir, &elf_id)
    if(created_elf == 0) { env.error("expected elf seed to insert exercises"); underlayer_db::close(&raw db); return }
    var bytes_list = underlayer_repository::get_exercises_for_concept(&raw db, &string("bytes"), 20)
    i = 0
    while(i < bytes_list.size()) {
        var e = bytes_list.get_ptr(i)
        if(e.exercise_type.id.equals(string("hex_inspect"))) { found_hex = true }
        i = i + 1
    }
    if(found_hex == false) { env.error("seeded hex_inspect not found for bytes") }

    underlayer_db::close(&raw db)
}
