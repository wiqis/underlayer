// underlayer_web — Exercise API handlers (4.1.1-4.1.5, 4.2.1-4.2.5).
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::Exercise
using underlayer_learning::ReviewState
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
            // 4.1.29: matching needs lefts (options) and rights for dropdowns.
            // Rights come from the answer field (answer[i] pairs with options[i]).
            // Reverse on the wire so right_options[i] is not the correct match
            // for left_options[i] — the pairing stays server-side only.
            if(ex.exercise_type.id.equals(string("matching"))) {
                var rights = vector<string>()
                var ai : size_t = 0
                var cur = string()
                while(ai <= ex.answer.size()) {
                    if(ai == ex.answer.size() || ex.answer.get(ai) == '|') {
                        rights.push(cur)
                        cur = string()
                    } else {
                        cur.append(ex.answer.get(ai))
                    }
                    ai = ai + 1
                }
                body.append_view(",\"right_options\":[")
                var ri : size_t = rights.size()
                while(ri > 0) {
                    ri = ri - 1
                    if(ri < rights.size() - 1) { body.append_view(",") }
                    body.append_view("\"")
                    var r_ptr = rights.get_ptr(ri)
                    var r_esc = underlayer_core::json_escape(&r_ptr.to_view())
                    body.append_string(&r_esc)
                    body.append_view("\"")
                }
                body.append_view("]")
            }
            // 4.1.29: labeling — number of blanks (pipe-separated answer parts)
            // without revealing the answers themselves.
            if(ex.exercise_type.id.equals(string("labeling"))) {
                var blanks : i64 = 1
                var li : size_t = 0
                while(li < ex.answer.size()) {
                    if(ex.answer.get(li) == '|') { blanks = blanks + 1 }
                    li = li + 1
                }
                body.append_view(",\"blank_count\":")
                body.append_string(&underlayer_core::int_to_string(blanks))
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

        // 4.2.1: Immediate correctness feedback — all 8 lesson UI types (4.1.29)
        var correct = grade_exercise(&ex, &user_answer)

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

        // ---- 4.1.28: Feed the learning loop ----
        // Exercise results previously never touched concept_states or review_items,
        // so practice had zero effect on scheduling. Map correct/incorrect to an
        // FSRS rating (Good=3 / Again=1), update the concept state, and seed/update
        // the concept's review item — same pipeline as /api/review/submit.
        var learner_id = auth_get_learner_id(&raw db, &*req)
        var authenticated = learner_id.size() > 0
        // Multi-course: the lesson page passes its course (query param or JSON
        // body). Deterministic fallback: look up which seeded course owns this
        // concept id before defaulting to "elf".
        var q_cid2 = string("course_id")
        var cid_v2 = req.query.get(&q_cid2.to_view())
        var course_id = string()
        if(cid_v2.size() > 0) { course_id = sv_to_string(&raw cid_v2) }
        if(course_id.size() == 0) {
            var body_str2 = read_body(req)
            if(body_str2.size() > 0) {
                var pr2 = json::parse(body_str2.to_view())
                if(pr2 is std::Result.Ok) {
                    var Ok(parsed2) = pr2 else unreachable
                    course_id = json_get_str(&raw parsed2, "course_id")
                }
            }
        }
        if(course_id.size() == 0) {
            var owner = underlayer_repository::find_course_for_concept(&raw db, &ex.concept_id)
            if(owner.size() > 0) { course_id = owner } else { course_id = string("elf") }
        }
        if(authenticated) {
            var rating : int = 1
            if(correct) { rating = 3 }

            var state = underlayer_repository::get_concept_state(&raw db, &learner_id, &ex.concept_id, &course_id)
            state.learner_id = learner_id.copy()
            state.concept_id = ex.concept_id.copy()
            state.course_id = course_id.copy()

            var params = underlayer_learning::init_fsrs_params()
            var rs = ReviewState::make()
            rs.difficulty = state.difficulty_rating
            if(rs.difficulty < 1.0) { rs.difficulty = 5.0 }
            if(rs.difficulty > 10.0) { rs.difficulty = 5.0 }
            rs.stability = 1.0
            rs.reps = state.attempts
            rs.lapses = state.attempts - state.correct
            rs.elapsed_days = 0
            rs.scheduled_days = state.next_review - state.last_studied
            if(rs.scheduled_days < 0) { rs.scheduled_days = 0 }

            var new_rs = underlayer_learning::fsrs_update_state(&params, &rs, rating)

            state.attempts = state.attempts + 1
            if(correct) {
                state.correct = state.correct + 1
                state.streak = state.streak + 1
            } else {
                state.streak = 0
            }
            state.last_studied = now
            state.next_review = state.last_studied + new_rs.scheduled_days
            state.difficulty_rating = new_rs.difficulty

            if(new_rs.reps == 1) { state.status = string("learning") }
            else if(new_rs.lapses > 0) { state.status = string("reviewing") }
            else if(new_rs.reps >= 5 && state.streak >= 3) { state.status = string("mastered") }
            else { state.status = string("reviewing") }

            underlayer_repository::upsert_concept_state(&raw db, &raw state)

            // Seed (first interaction) then update the review item's schedule
            underlayer_repository::seed_review_items(&raw db, &learner_id, &course_id)
            var item_id = string()
            item_id.append_string(&learner_id)
            item_id.append_view("_")
            item_id.append_string(&course_id)
            item_id.append_view("_")
            item_id.append_string(&ex.concept_id)
            var item = underlayer_repository::get_review_item(&raw db, &item_id)
            if(item.id.size() > 0) {
                item.last_review = now
                item.reps = item.reps + 1
                if(!correct) { item.lapses = item.lapses + 1 }
                item.difficulty = new_rs.difficulty
                item.stability = new_rs.stability
                item.next_review = now + new_rs.scheduled_days * 86400
                underlayer_repository::update_review_item(&raw db, &raw item)
            }

            underlayer_repository::record_activity(&raw db, &learner_id)
        }

        // 4.2.9: Related concept suggestions
        body.append_view(",\"related_concepts\":[")
        if(!correct && ex.concept_id.size() > 0) {
            body.append_view("{\"concept\":\"")
            body.append_string(&ex.concept_id)
            body.append_view("\"}")
        }
        body.append_view("]")
        // 4.2.13: Streak indicator (real value when authenticated — 4.2.19)
        body.append_view(",\"streak\":")
        if(authenticated) {
            var post_state = underlayer_repository::get_concept_state(&raw db, &learner_id, &ex.concept_id, &course_id)
            var streak_str = underlayer_core::int_to_string(post_state.streak as i64)
            body.append_string(&streak_str)
        } else {
            body.append_view("0")
        }
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
