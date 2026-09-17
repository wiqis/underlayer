// underlayer_web — Review session handlers.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::ReviewItem
using underlayer_models::ConceptState
using underlayer_learning::ReviewState

public namespace underlayer_web {

    // 5.1.1-5.1.5: Review session types via mode parameter
    // mode=new (5.1.1), due (5.1.2), cram (5.1.3), targeted (5.1.4), weakness (5.1.5)
    public func handle_review_start(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var course_id = string("elf")

        // Check for mode parameter (5.1.1-5.1.5)
        var q_mode = string("mode")
        var mode_v = req.query.get(&q_mode.to_view())
        var mode = string("due")
        if(mode_v.size() > 0) {
            mode = sv_to_string(&raw mode_v)
        }

        // Check for targeted concept (5.1.4)
        var q_concept = string("concept_id")
        var concept_v = req.query.get(&q_concept.to_view())

        // 2.4.21: lazily seed review items so the queue is never permanently empty
        underlayer_repository::seed_review_items(&raw db, &learner_id, &course_id)

        var due_items : std::vector<underlayer_models::ReviewItem> = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, 10)

        // 5.1.3: Cramming mode — return all review items (ignore next_review)
        if(mode.equals(string("cram"))) {
            due_items = underlayer_repository::get_all_review_items(&raw db, &learner_id, &course_id, 50)
        }
        // 1.2.28: Lightning mode — only new items (never reviewed)
        if(mode.equals(string("lightning"))) {
            var filtered = std::vector<underlayer_models::ReviewItem>()
            var fi : size_t = 0
            while(fi < due_items.size()) {
                var item = due_items.get_ptr(fi)
                if(item.reps == 0) {
                    var copy = underlayer_models::ReviewItem::make()
                    copy.id = item.id.copy()
                    copy.learner_id = item.learner_id.copy()
                    copy.concept_id = item.concept_id.copy()
                    copy.course_id = item.course_id.copy()
                    copy.item_type = item.item_type.copy()
                    copy.front = item.front.copy()
                    copy.back = item.back.copy()
                    copy.difficulty = item.difficulty
                    copy.stability = item.stability
                    copy.retrievability = item.retrievability
                    copy.next_review = item.next_review
                    copy.last_review = item.last_review
                    copy.reps = item.reps
                    copy.lapses = item.lapses
                    copy.ease_factor = item.ease_factor
                    filtered.push(copy)
                }
                fi = fi + 1
            }
            due_items = filtered
        }
        // 1.2.29: Review mode — only due items (already reviewed, no new)
        if(mode.equals(string("review"))) {
            var filtered = std::vector<underlayer_models::ReviewItem>()
            var fi : size_t = 0
            while(fi < due_items.size()) {
                var item = due_items.get_ptr(fi)
                if(item.reps > 0) {
                    var copy = underlayer_models::ReviewItem::make()
                    copy.id = item.id.copy()
                    copy.learner_id = item.learner_id.copy()
                    copy.concept_id = item.concept_id.copy()
                    copy.course_id = item.course_id.copy()
                    copy.item_type = item.item_type.copy()
                    copy.front = item.front.copy()
                    copy.back = item.back.copy()
                    copy.difficulty = item.difficulty
                    copy.stability = item.stability
                    copy.retrievability = item.retrievability
                    copy.next_review = item.next_review
                    copy.last_review = item.last_review
                    copy.reps = item.reps
                    copy.lapses = item.lapses
                    copy.ease_factor = item.ease_factor
                    filtered.push(copy)
                }
                fi = fi + 1
            }
            due_items = filtered
        }
        // 5.1.7: Speed review — timed reviews (3 seconds per item)
        var time_per_item = 0
        if(mode.equals(string("speed"))) {
            time_per_item = 3
        }
        // 5.1.8: Deep review — with explanations and context
        var include_explanations = false
        if(mode.equals(string("deep"))) {
            include_explanations = true
        }
        // 5.1.9: Mixed mode — learn new + review old (default, no filtering)
        // 5.1.10: Custom review — user-selected items (via item_ids query param)
        if(mode.equals(string("custom"))) {
            var q_items = string("item_ids")
            var items_v = req.query.get(&q_items.to_view())
            if(items_v.size() > 0) {
                var items_str = sv_to_string(&raw items_v)
                var filtered = std::vector<underlayer_models::ReviewItem>()
                var fi : size_t = 0
                while(fi < due_items.size()) {
                    var item = due_items.get_ptr(fi)
                    // Simple substring match to check if this item is in the list
                    var item_copy = item.id.copy()
                    var items_copy = items_str.copy()
                    var found = false
                    if(items_copy.size() >= item_copy.size()) {
                        var ti : size_t = 0
                        while(ti <= items_copy.size() - item_copy.size()) {
                            var match = true
                            var qi : size_t = 0
                            while(qi < item_copy.size()) {
                                if(items_copy.get(ti + qi) != item_copy.get(qi)) { match = false }
                                qi = qi + 1
                            }
                            if(match) { found = true }
                            ti = ti + 1
                        }
                    }
                    if(found) {
                        var copy = underlayer_models::ReviewItem::make()
                        copy.id = item.id.copy()
                        copy.learner_id = item.learner_id.copy()
                        copy.concept_id = item.concept_id.copy()
                        copy.course_id = item.course_id.copy()
                        copy.item_type = item.item_type.copy()
                        copy.front = item.front.copy()
                        copy.back = item.back.copy()
                        copy.difficulty = item.difficulty
                        copy.stability = item.stability
                        copy.retrievability = item.retrievability
                        copy.next_review = item.next_review
                        copy.last_review = item.last_review
                        copy.reps = item.reps
                        copy.lapses = item.lapses
                        copy.ease_factor = item.ease_factor
                        filtered.push(copy)
                    }
                    fi = fi + 1
                }
                due_items = filtered
            }
        }
        // 5.1.4: Targeted review — filter to specific concept
        if(mode.equals(string("targeted")) && concept_v.size() > 0) {
            var target_concept = sv_to_string(&raw concept_v)
            var filtered = std::vector<underlayer_models::ReviewItem>()
            var fi : size_t = 0
            while(fi < due_items.size()) {
                var item = due_items.get_ptr(fi)
                if(item.concept_id.equals(&target_concept)) {
                    var copy = underlayer_models::ReviewItem::make()
                    copy.id = item.id.copy()
                    copy.learner_id = item.learner_id.copy()
                    copy.concept_id = item.concept_id.copy()
                    copy.course_id = item.course_id.copy()
                    copy.item_type = item.item_type.copy()
                    copy.front = item.front.copy()
                    copy.back = item.back.copy()
                    copy.difficulty = item.difficulty
                    copy.stability = item.stability
                    copy.retrievability = item.retrievability
                    copy.next_review = item.next_review
                    copy.last_review = item.last_review
                    copy.reps = item.reps
                    copy.lapses = item.lapses
                    copy.ease_factor = item.ease_factor
                    filtered.push(copy)
                }
                fi = fi + 1
            }
            due_items = filtered
        }
        // 5.1.5: Weakness repair — get states, find weak concepts, filter items
        if(mode.equals(string("weakness"))) {
            var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
            var weak_concepts = std::vector<std::string>()
            var si : size_t = 0
            while(si < states.size()) {
                var state = states.get_ptr(si)
                if(state.attempts > 0) {
                    var accuracy = (state.correct as f64) / (state.attempts as f64)
                    if(accuracy < 0.6) {
                        weak_concepts.push(state.concept_id.copy())
                    }
                }
                si = si + 1
            }
            var filtered = std::vector<underlayer_models::ReviewItem>()
            var fi : size_t = 0
            while(fi < due_items.size()) {
                var item = due_items.get_ptr(fi)
                var wi : size_t = 0
                while(wi < weak_concepts.size()) {
                    var wc_ptr = weak_concepts.get_ptr(wi)
                    var wc_copy = wc_ptr.copy()
                    if(item.concept_id.equals(&wc_copy)) {
                        var copy = underlayer_models::ReviewItem::make()
                        copy.id = item.id.copy()
                        copy.learner_id = item.learner_id.copy()
                        copy.concept_id = item.concept_id.copy()
                        copy.course_id = item.course_id.copy()
                        copy.item_type = item.item_type.copy()
                        copy.front = item.front.copy()
                        copy.back = item.back.copy()
                        copy.difficulty = item.difficulty
                        copy.stability = item.stability
                        copy.retrievability = item.retrievability
                        copy.next_review = item.next_review
                        copy.last_review = item.last_review
                        copy.reps = item.reps
                        copy.lapses = item.lapses
                        copy.ease_factor = item.ease_factor
                        filtered.push(copy)
                    }
                    wi = wi + 1
                }
                fi = fi + 1
            }
            due_items = filtered
        }

        var now = underlayer_core::current_timestamp()
        var session_id = underlayer_core::int_to_string(now)
        underlayer_repository::create_session(&raw db, &raw session_id, &raw learner_id, now)

        var body = std::string("{\"session_id\":\"")
        body.append_string(&session_id)
        body.append_view("\",\"items\":[")
        var i : size_t = 0
        while(i < due_items.size()) {
            if(i > 0) { body.append_view(",") }
            var item = due_items.get_ptr(i)
            body.append_view("{\"id\":\"")
            body.append_string(&item.id)
            body.append_view("\",\"concept\":\"")
            body.append_string(&item.concept_id)
            body.append_view("\",\"type\":\"")
            body.append_string(&item.item_type)
            body.append_view("\",\"front\":\"")
            body.append_string(&item.front)
            body.append_view("\",\"back\":\"")
            body.append_string(&item.back)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("],\"total\":")
        var total_str = underlayer_core::int_to_string(due_items.size() as i64)
        body.append_string(&total_str)
        body.append_view(",\"started_at\":")
        body.append_string(&session_id)
        // 1.2.15: Estimated time remaining (~30s per item)
        var est_secs : i64 = (due_items.size() as i64) * 30
        body.append_view(",\"est_seconds_remaining\":")
        var est_out = underlayer_core::int_to_string(est_secs)
        body.append_string(&est_out)
        body.append_view(",\"mode\":\"")
        body.append_string(&mode)
        body.append_view("\",\"break_reminder_seconds\":1500")
        body.append_view(",\"auto_save_interval_seconds\":30")
        body.append_view(",\"time_per_item_seconds\":")
        var tpi_out = underlayer_core::int_to_string(time_per_item as i64)
        body.append_string(&tpi_out)
        body.append_view(",\"include_explanations\":")
        if(include_explanations) { body.append_view("true") } else { body.append_view("false") }
        body.append_view(",\"session_length_suggestion\":")
        // 1.2.26: Suggest session length based on energy level
        var q_energy = string("energy")
        var energy_v = req.query.get(&q_energy.to_view())
        if(energy_v.size() > 0) {
            var energy = sv_to_string(&raw energy_v)
            if(energy.equals(string("high"))) { body.append_view("1800") }
            else if(energy.equals(string("medium"))) { body.append_view("900") }
            else if(energy.equals(string("low"))) { body.append_view("300") }
            else { body.append_view("900") }
        } else {
            body.append_view("900")
        }
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    public func handle_review_submit(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var q_cid = string("concept_id")
        var q_crsid = string("course_id")
        var q_rat = string("rating")
        var q_sid = string("session_id")
        var q_time = string("time_spent_ms")
        var cid_v = req.query.get(&q_cid.to_view())
        var crsid_v = req.query.get(&q_crsid.to_view())
        var rat_v = req.query.get(&q_rat.to_view())
        var sid_v = req.query.get(&q_sid.to_view())
        var time_v = req.query.get(&q_time.to_view())
        if(cid_v.size() == 0 || crsid_v.size() == 0 || rat_v.size() == 0) {
            send_error(res, 400u, &string("missing query params: concept_id, course_id, rating"))
            return
        }
        var concept_id = sv_to_string(&raw cid_v)
        var course_id = sv_to_string(&raw crsid_v)
        var rating_str = sv_to_string(&raw rat_v)
        var learner_id = auth_get_learner_id(&raw db, &*req)
        if(learner_id.size() == 0) { learner_id = string("demo") }

        var rating : int = 3
        if(rating_str.equals(string("again")) || rating_str.equals(string("1"))) { rating = 1 }
        if(rating_str.equals(string("hard")) || rating_str.equals(string("2"))) { rating = 2 }
        if(rating_str.equals(string("good")) || rating_str.equals(string("3"))) { rating = 3 }
        if(rating_str.equals(string("easy")) || rating_str.equals(string("4"))) { rating = 4 }

        var state = underlayer_repository::get_concept_state(&raw db, &learner_id, &concept_id, &course_id)
        state.learner_id = learner_id.copy()
        state.concept_id = concept_id.copy()
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
        if(rating >= 3) { state.correct = state.correct + 1 }
        if(rating >= 3) { state.streak = state.streak + 1 } else { state.streak = 0 }
        state.last_studied = underlayer_core::current_timestamp()
        state.next_review = state.last_studied + new_rs.scheduled_days
        state.difficulty_rating = new_rs.difficulty

        if(new_rs.reps == 1) { state.status = string("learning") }
        else if(new_rs.lapses > 0) { state.status = string("reviewing") }
        else if(new_rs.reps >= 5 && state.streak >= 3) { state.status = string("mastered") }
        else { state.status = string("reviewing") }

        underlayer_repository::upsert_concept_state(&raw db, &raw state)
        underlayer_repository::record_activity(&raw db, &learner_id)
        underlayer_repository::run_achievement_checks(&raw db, &learner_id)

        // 1.2.16: Compute session accuracy from state
        var session_accuracy : f64 = 0.0
        if(state.attempts > 0) {
            session_accuracy = (state.correct as f64) / (state.attempts as f64)
        }
        // 1.2.17: Current streak from state
        var current_streak = state.streak

        // Record session item if session_id provided (1.2.6, 1.2.7)
        if(sid_v.size() > 0) {
            var session_id = sv_to_string(&raw sid_v)
            var time_spent : i64 = 0
            if(time_v.size() > 0) {
                time_spent = underlayer_repository::parse_i64(time_v)
            }
            underlayer_repository::record_session_item(&raw db, &session_id, &concept_id, rating, time_spent)
        }

        var resp = string("{\"status\":\"ok\",\"rating\":")
        var rating_out = underlayer_core::int_to_string(rating as i64)
        resp.append_string(&rating_out)
        resp.append_view(",\"next_interval\":")
        var interval_out = underlayer_core::int_to_string(new_rs.scheduled_days)
        resp.append_string(&interval_out)
        resp.append_view(",\"streak\":")
        var streak_out = underlayer_core::int_to_string(state.streak as i64)
        resp.append_string(&streak_out)
        resp.append_view(",\"new_status\":\"")
        resp.append_string(&state.status)
        resp.append_view("\"")
        // 1.1.15: Include ease_factor in response
        resp.append_view(",\"ease_factor\":")
        var ef_out = underlayer_learning::f64_to_string(new_rs.ease_factor)
        resp.append_string(&ef_out)
        // 1.1.29: Why-this-interval explanation
        resp.append_view(",\"stability\":")
        var stab_out = underlayer_learning::f64_to_string(new_rs.stability)
        resp.append_string(&stab_out)
        resp.append_view(",\"difficulty\":")
        var diff_out = underlayer_learning::f64_to_string(new_rs.difficulty)
        resp.append_string(&diff_out)
        resp.append_view(",\"reps\":")
        var reps_out = underlayer_core::int_to_string(new_rs.reps as i64)
        resp.append_string(&reps_out)
        resp.append_view(",\"lapses\":")
        var lapses_out = underlayer_core::int_to_string(new_rs.lapses as i64)
        resp.append_string(&lapses_out)
        resp.append_view(",\"interval_days\":")
        resp.append_string(&interval_out)
        // 1.2.16: Session accuracy (real-time)
        var acc_out = underlayer_learning::f64_to_string(session_accuracy)
        resp.append_view(",\"session_accuracy\":")
        resp.append_string(&acc_out)
        // 1.2.17: Current streak
        resp.append_view(",\"current_streak\":")
        var cs_out = underlayer_core::int_to_string(current_streak as i64)
        resp.append_string(&cs_out)
        // P2 4.2.16/4.2.17: Mistake pattern + personalized feedback
        var pattern_states = std::vector<underlayer_models::ConceptState>()
        pattern_states.push(state)
        var patterns = underlayer_learning::detect_mistake_patterns(&raw pattern_states)
        var none_pat = string("none")
        var feedback = string()
        if(patterns.size() > 0) {
            var p0 = patterns.get_ptr(0)
            resp.append_view(",\"mistake_pattern\":\"")
            resp.append_string(&p0.pattern)
            resp.append_view("\"")
            feedback = underlayer_learning::personalized_feedback(p0)
        } else {
            resp.append_view(",\"mistake_pattern\":\"")
            resp.append_string(&none_pat)
            resp.append_view("\"")
        }
        resp.append_view(",\"personalized_feedback\":\"")
        var fb_escaped = underlayer_core::json_escape(&feedback.to_view())
        resp.append_string(&fb_escaped)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    public func handle_review_end(db : &DbClient, req : *mut http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        underlayer_repository::finish_session(&raw db, &raw session_id, 0, 0)

        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    public func handle_review_due(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var course_id = string("elf")
        var limit : int = 10

        // 2.4.21: lazily seed review items so the queue is never permanently empty
        underlayer_repository::seed_review_items(&raw db, &learner_id, &course_id)

        var due_items = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, limit)
        var body = std::string("{\"items\":[")
        var i : size_t = 0
        while(i < due_items.size()) {
            if(i > 0) { body.append_view(",") }
            var item = due_items.get_ptr(i)
            body.append_view("{\"id\":\"")
            body.append_string(&item.id)
            body.append_view("\",\"concept\":\"")
            body.append_string(&item.concept_id)
            body.append_view("\",\"type\":\"")
            body.append_string(&item.item_type)
            body.append_view("\",\"front\":\"")
            body.append_string(&item.front)
            body.append_view("\",\"back\":\"")
            body.append_string(&item.back)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("],\"total\":")
        var total_str = underlayer_core::int_to_string(due_items.size() as i64)
        body.append_string(&total_str)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // ---- Session History (1.2.21, 1.2.22, 1.2.23, 1.2.24) ----
    public func handle_session_history(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var sessions = underlayer_repository::get_learner_sessions(&raw db, &learner_id, 20)

        var body = std::string("{\"sessions\":[")
        var i : size_t = 0
        while(i < sessions.size()) {
            if(i > 0) { body.append_view(",") }
            var s = sessions.get_ptr(i)
            body.append_view("{\"id\":\"")
            body.append_string(&s.id)
            body.append_view("\",\"start_time\":")
            var st_str = underlayer_core::int_to_string(s.start_time)
            body.append_string(&st_str)
            body.append_view(",\"end_time\":")
            var et_str = underlayer_core::int_to_string(s.end_time)
            body.append_string(&et_str)
            body.append_view(",\"type\":\"")
            body.append_string(&s.session_type)
            body.append_view("\",\"attempted\":")
            var ea_str = underlayer_core::int_to_string(s.exercises_attempted as i64)
            body.append_string(&ea_str)
            body.append_view(",\"correct\":")
            var ec_str = underlayer_core::int_to_string(s.exercises_correct as i64)
            body.append_string(&ec_str)
            // 1.2.23: Accuracy per session
            body.append_view(",\"accuracy\":")
            var acc : f64 = 0.0
            if(s.exercises_attempted > 0) {
                acc = (s.exercises_correct as f64) / (s.exercises_attempted as f64)
            }
            var acc_out = underlayer_learning::f64_to_string(acc)
            body.append_string(&acc_out)
            // 1.2.24: Speed per session (ms per exercise)
            body.append_view(",\"speed_ms\":")
            var elapsed = s.end_time - s.start_time
            var speed_ms : i64 = 0
            if(s.exercises_attempted > 0 && elapsed > 0) {
                speed_ms = elapsed * 1000 / (s.exercises_attempted as i64)
            }
            var speed_out = underlayer_core::int_to_string(speed_ms)
            body.append_string(&speed_out)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("],\"trends\":{")
        // Compute trends across sessions
        if(sessions.size() >= 2) {
            var first = sessions.get_ptr(0)
            var last = sessions.get_ptr(sessions.size() - 1)
            var first_acc : f64 = 0.0
            var last_acc : f64 = 0.0
            if(first.exercises_attempted > 0) {
                first_acc = (first.exercises_correct as f64) / (first.exercises_attempted as f64)
            }
            if(last.exercises_attempted > 0) {
                last_acc = (last.exercises_correct as f64) / (last.exercises_attempted as f64)
            }
            var acc_trend = string("stable")
            if(last_acc > first_acc + 0.05) { acc_trend = string("improving") }
            else if(last_acc < first_acc - 0.05) { acc_trend = string("declining") }
            body.append_view("\"accuracy_trend\":\"")
            body.append_string(&acc_trend)
            body.append_view("\"")
        } else {
            body.append_view("\"accuracy_trend\":\"insufficient_data\"")
        }
        body.append_view("}}")
        send_json_str(res, &raw body)
    }

    // ---- Session Detail (1.2.22) ----
    public func handle_session_detail(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            var path = req.path.to_view()
            var segments = underlayer_core::path_segments(&path)
            if(segments.size() >= 2) {
                sid_v = *segments.get_ptr(segments.size() - 1)
            }
        }
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing session_id param or path segment"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)

        var items = underlayer_repository::get_session_items(&raw db, &session_id)
        var stats = underlayer_repository::get_session_stats(&raw db, &session_id)

        var body = std::string("{\"session_id\":\"")
        body.append_string(&session_id)
        body.append_view("\",\"stats\":{\"total\":")
        var t_str = underlayer_core::int_to_string(stats.total_items as i64)
        body.append_string(&t_str)
        body.append_view(",\"correct\":")
        var c_str = underlayer_core::int_to_string(stats.correct_items as i64)
        body.append_string(&c_str)
        body.append_view(",\"time_ms\":")
        var tm_str = underlayer_core::int_to_string(stats.total_time_ms)
        body.append_string(&tm_str)
        body.append_view("},\"items\":[")
        var i : size_t = 0
        while(i < items.size()) {
            if(i > 0) { body.append_view(",") }
            var item = items.get_ptr(i)
            body.append_view("{\"concept\":\"")
            body.append_string(&item.concept_id)
            body.append_view("\",\"rating\":")
            var r_str = underlayer_core::int_to_string(item.rating as i64)
            body.append_string(&r_str)
            body.append_view(",\"time_ms\":")
            var it_str = underlayer_core::int_to_string(item.time_spent_ms)
            body.append_string(&it_str)
            body.append_view(",\"at\":")
            var a_str = underlayer_core::int_to_string(item.reviewed_at)
            body.append_string(&a_str)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // ---- Session Pause (1.2.9) ----
    public func handle_session_pause(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        underlayer_repository::pause_session(&raw db, &raw session_id)
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"state\":\"paused\"}")
        send_json_str(res, &raw resp)
    }

    // ---- Session Resume (1.2.10) ----
    public func handle_session_resume(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        underlayer_repository::resume_session(&raw db, &raw session_id)
        // Return items already reviewed so client can rebuild state
        var items = underlayer_repository::get_session_items(&raw db, &session_id)
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"state\":\"active\",\"reviewed\":")
        var t_str = underlayer_core::int_to_string(items.size() as i64)
        resp.append_string(&t_str)
        resp.append_view("}")
        send_json_str(res, &raw resp)
    }

    // ---- Session Abort (1.2.11) ----
    public func handle_session_abort(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        underlayer_repository::abort_session(&raw db, &raw session_id)
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"state\":\"aborted\"}")
        send_json_str(res, &raw resp)
    }

    // ---- Session Undo (1.2.12) ----
    public func handle_session_undo(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var sid_v = req.query.get(&q_sid.to_view())
        if(sid_v.size() == 0) {
            send_error(res, 400u, &string("missing query param: session_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        var undone = underlayer_repository::undo_last_item(&raw db, &raw session_id)
        if(!undone) {
            send_error(res, 404u, &string("no items to undo"))
            return
        }
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"undone\":true}")
        send_json_str(res, &raw resp)
    }

    // ---- Session Skip (1.2.13) ----
    public func handle_session_skip(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var q_sid = string("session_id")
        var q_cid = string("concept_id")
        var sid_v = req.query.get(&q_sid.to_view())
        var cid_v = req.query.get(&q_cid.to_view())
        if(sid_v.size() == 0 || cid_v.size() == 0) {
            send_error(res, 400u, &string("missing query params: session_id, concept_id"))
            return
        }
        var session_id = sv_to_string(&raw sid_v)
        var concept_id = sv_to_string(&raw cid_v)
        underlayer_repository::skip_item(&raw db, &raw session_id, &raw concept_id)
        var resp = string("{\"status\":\"ok\",\"session_id\":\"")
        resp.append_string(&session_id)
        resp.append_view("\",\"skipped\":\"")
        resp.append_string(&concept_id)
        resp.append_view("\"}")
        send_json_str(res, &raw resp)
    }

    // 1.2.25: Session recommendations — suggest session type based on due items
    public func handle_session_recommendations(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var course_id = string("elf")
        var due_items = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, 50)
        var new_count : int = 0
        var review_count : int = 0
        var i : size_t = 0
        while(i < due_items.size()) {
            var item = due_items.get_ptr(i)
            if(item.reps == 0) { new_count = new_count + 1 }
            else { review_count = review_count + 1 }
            i = i + 1
        }
        var body = std::string("{\"due_count\":")
        var dc_str = underlayer_core::int_to_string(due_items.size() as i64)
        body.append_view(dc_str.to_view())
        body.append_view(",\"new_count\":")
        var nc_str = underlayer_core::int_to_string(new_count as i64)
        body.append_view(nc_str.to_view())
        body.append_view(",\"review_count\":")
        var rc_str = underlayer_core::int_to_string(review_count as i64)
        body.append_view(rc_str.to_view())
        body.append_view(",\"recommendations\":[")
        // Recommend based on due items
        var first = true
        if(new_count > 0) {
            body.append_view("{\"type\":\"new\",\"label\":\"Learn New Concepts\",\"count\":")
            body.append_view(nc_str.to_view())
            body.append_view(",\"estimated_minutes\":")
            var est_new = underlayer_core::int_to_string((new_count * 2) as i64)
            body.append_view(est_new.to_view())
            body.append_view("}")
            first = false
        }
        if(review_count > 0) {
            if(!first) { body.append_view(",") }
            body.append_view("{\"type\":\"due\",\"label\":\"Review Due Items\",\"count\":")
            body.append_view(rc_str.to_view())
            body.append_view(",\"estimated_minutes\":")
            var est_rev = underlayer_core::int_to_string((review_count * 1) as i64)
            body.append_view(est_rev.to_view())
            body.append_view("}")
            first = false
        }
        if(new_count > 0 && review_count > 0) {
            if(!first) { body.append_view(",") }
            body.append_view("{\"type\":\"mixed\",\"label\":\"Mixed Session\",\"count\":")
            var mixed_str = underlayer_core::int_to_string(due_items.size() as i64)
            body.append_view(mixed_str.to_view())
            body.append_view(",\"estimated_minutes\":")
            var est_mixed = underlayer_core::int_to_string(((new_count * 2 + review_count * 1) / 2) as i64)
            body.append_view(est_mixed.to_view())
            body.append_view("}")
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // 1.2.27: Session recommendations — suggest time of day based on past performance
    public func handle_session_time_recommendation(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var sessions = underlayer_repository::get_learner_sessions(&raw db, &learner_id, 50)

        // Analyze which hours have best accuracy
        var hourly_accuracy : vector<f64> = vector<f64>()
        var hourly_count : vector<i64> = vector<i64>()
        var hi : size_t = 0
        while(hi < 24) {
            hourly_accuracy.push(0.0)
            hourly_count.push(0)
            hi = hi + 1
        }
        var si : size_t = 0
        while(si < sessions.size()) {
            var s = sessions.get_ptr(si)
            // Approximate hour from timestamp (hour = (timestamp % 86400) / 3600)
            var hour = ((s.start_time % 86400) / 3600) as size_t
            if(hour < 24) {
                var acc : f64 = 0.0
                if(s.exercises_attempted > 0) {
                    acc = (s.exercises_correct as f64) / (s.exercises_attempted as f64)
                }
                var prev_acc = hourly_accuracy.get(hour)
                var prev_count = hourly_count.get(hour)
                hourly_accuracy.set(hour, prev_acc + acc)
                hourly_count.set(hour, prev_count + 1)
            }
            si = si + 1
        }

        // Find best hour
        var best_hour : i64 = -1
        var best_acc : f64 = 0.0
        var hi2 : size_t = 0
        while(hi2 < 24) {
            var cnt = hourly_count.get(hi2)
            if(cnt > 0) {
                var avg = hourly_accuracy.get(hi2) / (cnt as f64)
                if(avg > best_acc) {
                    best_acc = avg
                    best_hour = hi2 as i64
                }
            }
            hi2 = hi2 + 1
        }

        var body = string("{\"best_hour\":")
        var bh_out = underlayer_core::int_to_string(best_hour)
        body.append_string(&bh_out)
        body.append_view(",\"best_accuracy\":")
        var ba_out = underlayer_learning::f64_to_string(best_acc)
        body.append_string(&ba_out)
        body.append_view(",\"suggestion\":\"")
        if(best_hour >= 0) {
            if(best_hour < 12) { body.append_view("Morning learner") }
            else if(best_hour < 17) { body.append_view("Afternoon learner") }
            else { body.append_view("Evening learner") }
        } else {
            body.append_view("Complete more sessions to get personalized recommendations")
        }
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

}
