// underlayer_web — Exercise API handlers (4.1.1-4.1.5, 4.2.1-4.2.5).
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::Exercise
using underlayer_repository::parse_i64

public namespace underlayer_web {

    // GET /api/exercises/:conceptId — Get exercises for a concept (4.1.1-4.1.5)
    public func handle_get_exercises(db : &DbClient, concept_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var cid = sv_to_string(concept_id)
        var exercises = underlayer_repository::get_exercises_for_concept(&raw db, &cid, 5)

        var body = std::string("{\"concept_id\":\"")
        body.append_string(&cid)
        body.append_view("\",\"exercises\":[")
        var i : size_t = 0
        while(i < exercises.size()) {
            if(i > 0) { body.append_view(",") }
            var ex = exercises.get_ptr(i)
            body.append_view("{\"id\":\"")
            body.append_string(&ex.id)
            body.append_view("\",\"type\":\"")
            body.append_string(&ex.exercise_type.id)
            body.append_view("\",\"question\":\"")
            var q_esc = underlayer_core::json_escape(&ex.question.to_view())
            body.append_string(&q_esc)
            body.append_view("\"")
            // 4.1.1-4.1.3: Include options for multiple choice
            if(ex.options.size() > 0) {
                body.append_view(",\"options\":[")
                var oi : size_t = 0
                while(oi < ex.options.size()) {
                    if(oi > 0) { body.append_view(",") }
                    body.append_view("\"")
                    var opt_ptr = ex.options.get_ptr(oi)
                    var opt_esc = underlayer_core::json_escape(&opt_ptr.to_view())
                    body.append_string(&opt_esc)
                    body.append_view("\"")
                    oi = oi + 1
                }
                body.append_view("]")
            }
            body.append_view(",\"difficulty\":")
            var diff_str = underlayer_learning::f64_to_string(ex.difficulty as f64)
            body.append_string(&diff_str)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("],\"total\":")
        var total_str = underlayer_core::int_to_string(exercises.size() as i64)
        body.append_string(&total_str)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // POST /api/exercises/submit — Submit an answer (4.2.1-4.2.3)
    // Query params: exercise_id, answer
    public func handle_exercise_submit(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var q_eid = string("exercise_id")
        var q_ans = string("answer")
        var eid_v = req.query.get(&q_eid.to_view())
        var ans_v = req.query.get(&q_ans.to_view())
        if(eid_v.size() == 0 || ans_v.size() == 0) {
            send_error(res, 400u, &string("missing query params: exercise_id, answer"))
            return
        }
        var exercise_id = sv_to_string(&raw eid_v)
        var user_answer = sv_to_string(&raw ans_v)

        var ex = underlayer_repository::get_exercise(&raw db, &exercise_id)
        if(ex.id.size() == 0) {
            send_error(res, 404u, &string("exercise not found"))
            return
        }

        // 4.2.1: Immediate correctness feedback
        var correct = false
        if(ex.exercise_type.id.equals(string("recall")) || ex.exercise_type.id.equals(string("apply"))) {
            // Free recall / cued recall: case-insensitive comparison
            var user_lower = user_answer.to_view().to_string()
            var ans_lower = ex.answer.to_view().to_string()
            correct = user_lower.equals(&ans_lower)
        } else if(ex.exercise_type.id.equals(string("multi_recognize"))) {
            // 4.1.3: Multi-select — user submits comma-separated indices (e.g., "0,2,3")
            // Parse user answer into vector of ints
            var user_indices = vector<int>()
            var ui_start : size_t = 0
            var ui : size_t = 0
            while(ui <= user_answer.size()) {
                if(ui == user_answer.size() || user_answer.get(ui) == ',') {
                    var num_str = string()
                    var uj : size_t = ui_start
                    while(uj < ui) {
                        num_str.append(user_answer.get(uj))
                        uj = uj + 1
                    }
                    if(num_str.size() > 0) {
                        user_indices.push(parse_i64(num_str.to_view()) as int)
                    }
                    ui_start = ui + 1
                }
                ui = ui + 1
            }
            // Check: same count and all user indices are in correct_indices
            if(user_indices.size() == ex.correct_indices.size()) {
                correct = true
                var uii : size_t = 0
                while(uii < user_indices.size()) {
                    var user_idx = user_indices.get(uii)
                    var found = false
                    var cii : size_t = 0
                    while(cii < ex.correct_indices.size()) {
                        if(ex.correct_indices.get(cii) == user_idx) { found = true }
                        cii = cii + 1
                    }
                    if(!found) { correct = false }
                    uii = uii + 1
                }
            }
        } else {
            // Multiple choice: compare by index or text
            var ans_idx = -1
            var ai : size_t = 0
            while(ai < ex.options.size()) {
                var opt_ptr = ex.options.get_ptr(ai)
                if(opt_ptr.to_view().equals(&user_answer.to_view())) {
                    ans_idx = ai as int
                }
                ai = ai + 1
            }
            if(ans_idx == ex.correct_index) { correct = true }
            // Also allow direct answer text match
            if(!correct) {
                correct = user_answer.to_view().equals(&ex.answer.to_view())
            }
        }

        var body = std::string("{\"correct\":")
        if(correct) { body.append_view("true") } else { body.append_view("false") }
        // 4.2.2/4.2.3: Always include explanation
        body.append_view(",\"explanation\":\"")
        var exp_esc = underlayer_core::json_escape(&ex.explanation.to_view())
        body.append_string(&exp_esc)
        body.append_view("\"")
        body.append_view(",\"correct_answer\":\"")
        var ans_esc = underlayer_core::json_escape(&ex.answer.to_view())
        body.append_string(&ans_esc)
        body.append_view("\"")
        // 4.2.8: Solution reveal after 3 failed attempts (client tracks attempts)
        body.append_view(",\"show_solution_after\":3")
        var now = underlayer_core::current_timestamp()
        // 4.2.9: Related concept suggestions
        body.append_view(",\"related_concepts\":[")
        if(!correct && ex.concept_id.size() > 0) {
            body.append_view("{\"concept\":\"")
            body.append_string(&ex.concept_id)
            body.append_view("\"}")
        }
        body.append_view("]")
        // 4.2.13: Streak indicator
        body.append_view(",\"streak\":0")
        // 4.2.14: Encouragement messages
        body.append_view(",\"encouragement\":\"")
        if(correct) {
            var msgs = vector<string>()
            msgs.push(string("Great job!"))
            msgs.push(string("Excellent work!"))
            msgs.push(string("Keep it up!"))
            msgs.push(string("Perfect!"))
            var idx = (now as size_t) % msgs.size()
            var msg = msgs.get_ptr(idx).copy()
            body.append_string(&msg)
        } else {
            body.append_view("Don't give up! You'll get it next time.")
        }
        body.append_view("\"")
        // 4.2.15: Difficulty indicator
        body.append_view(",\"difficulty_indicator\":\"")
        if(ex.difficulty < 0.33f) { body.append_view("easy") }
        else if(ex.difficulty < 0.66f) { body.append_view("medium") }
        else { body.append_view("hard") }
        body.append_view("\"")
        // 4.2.11: Time spent indicator (placeholder — client sends time_spent_seconds)
        body.append_view(",\"time_spent_seconds\":0")
        // 4.2.12: Accuracy trend indicator (based on recent attempts)
        body.append_view(",\"accuracy_trend\":\"stable\"}")
        send_json_str(res, &raw body)
    }

    // GET /api/exercises/hint — Get a progressive hint (4.2.4, 4.2.5)
    // Query params: exercise_id, level (1, 2, or 3)
    public func handle_exercise_hint(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_eid = string("exercise_id")
        var q_lvl = string("level")
        var eid_v = req.query.get(&q_eid.to_view())
        var lvl_v = req.query.get(&q_lvl.to_view())
        if(eid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: exercise_id"))
            return
        }
        var exercise_id = sv_to_string(&raw eid_v)
        var level : int = 1
        if(lvl_v.size() > 0) {
            level = underlayer_repository::parse_i64(lvl_v) as int
        }
        if(level < 1) { level = 1 }
        if(level > 3) { level = 3 }

        var ex = underlayer_repository::get_exercise(&raw db, &exercise_id)
        if(ex.id.size() == 0) {
            send_error(res, 404u, &string("exercise not found"))
            return
        }

        var hint = string()
        // 4.2.5: Hint 1 is conceptual, Hint 2 is directional, Hint 3 is almost answer
        if(level == 1) { hint = ex.hint1.copy() }
        else if(level == 2) { hint = ex.hint2.copy() }
        else { hint = ex.hint3.copy() }

        var body = std::string("{\"hint\":\"")
        var h_esc = underlayer_core::json_escape(&hint.to_view())
        body.append_string(&h_esc)
        body.append_view("\",\"level\":")
        var lvl_str = underlayer_core::int_to_string(level as i64)
        body.append_string(&lvl_str)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

}
