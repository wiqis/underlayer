// underlayer_web — G1 diagnostic: items from C1's verified banks + a real scorer.
//
// VERIFICATION OF THE EXISTING SCORER (2026-11-28): POST
// /api/courses/:courseId/assess (handlers_learning_path.ch:107-201) does NOT
// score learner answers. It walks the course's own banks, checks each stored
// answer against itself, and returns a placement derived from that self-check;
// no request field carrying a learner response is read. It is therefore not a
// placement scorer and must not be used as one. These two routes are additive:
// the old assess route keeps its exact shape and callers.
//
// Every item comes from the seeded, verified exercise bank for a concept, and
// every returned start concept is taken from the course's own manifest order,
// never from a hardcoded index.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient
using underlayer_models::Exercise

public namespace underlayer_web {

    // First recognize item with real options, taken from the bank of each
    // manifest concept in order. At most `count` items, so the diagnostic is
    // the specified 5-8 items rather than the whole bank.
    public func diagnostic_items(db : *DbClient, course_id : &string, courses_dir : &string, count : int) : string {
        var course = underlayer_repository::load_course(courses_dir, course_id)
        var out = string("{\"course_id\":\"")
        var cid = underlayer_core::json_escape(&course_id.to_view())
        out.append_string(&cid)
        out.append_view("\",\"items\":[")
        var added = 0
        var ci : size_t = 0
        while(ci < course.concepts.size() && added < count) {
            var concept = course.concepts.at_ref(ci)
            var bank = underlayer_repository::get_exercises_for_concept(db, &concept.id, 4)
            var ei : size_t = 0
            while(ei < bank.size() && added < count) {
                var ex = bank.at_ref(ei)
                if(ex.options.size() >= 2 && ex.answer.size() > 0) {
                    if(added > 0) { out.append_view(",") }
                    out.append_view("{\"exercise_id\":\"")
                    var eid = underlayer_core::json_escape(&ex.id.to_view())
                    out.append_string(&eid)
                    out.append_view("\",\"concept_id\":\"")
                    var coid = underlayer_core::json_escape(&concept.id.to_view())
                    out.append_string(&coid)
                    out.append_view("\",\"question\":\"")
                    var q = underlayer_core::json_escape(&ex.question.to_view())
                    out.append_string(&q)
                    out.append_view("\",\"options\":[")
                    var oi : size_t = 0
                    while(oi < ex.options.size()) {
                        if(oi > 0) { out.append_view(",") }
                        var ov = ex.options.at_ref(oi).to_view()
                        var opt = underlayer_core::json_escape(&ov)
                        out.append_view("\"")
                        out.append_string(&opt)
                        out.append_view("\"")
                        oi = oi + 1
                    }
                    out.append_view("]}")
                    added = added + 1
                }
                ei = ei + 1
            }
            ci = ci + 1
        }
        out.append_view("],\"total\":")
        var t = underlayer_core::int_to_string(added as i64)
        out.append_string(&t)
        out.append_view("}")
        return out
    }

    public func handle_onboarding_diagnostic(db : *DbClient, courses_dir : &string, req : &http::Request) : http::Response {
        var course_id = string("elf")
        var key = string("course_id")
        var v = sv_or_empty(req.query.get(std::str.make_view(key.to_view())))
        if(v.size() > 0) { course_id = sv_to_string(&v) }
        var count = 6
        var ckey = string("count")
        var cv = sv_or_empty(req.query.get(std::str.make_view(ckey.to_view())))
        if(cv.size() > 0) {
            var cs = sv_to_string(&cv)
            var parsed = underlayer_repository::parse_int(cs.to_view())
            if(parsed >= 5 && parsed <= 8) { count = parsed }
        }
        var course = underlayer_repository::load_course(courses_dir, &course_id)
        if(course.id.size() == 0) {
            var err = string("course not found")
            return send_error(404u, &err)
        }
        var body = diagnostic_items(db, &course_id, courses_dir, count)
        return send_json_str(&body)
    }

    // A submitted answer is either the exact verified answer text, or the
    // 0-based index of the option the learner selected.
    private func answer_matches(ex : &Exercise, submitted : &string) : bool {
        if(submitted.size() == 0) { return false }
        if(submitted.equals(&ex.answer)) { return true }
        var idx = underlayer_repository::parse_int(submitted.to_view())
        if(idx >= 0 && idx < ex.options.size() as int) {
            var picked = ex.options.at_ref(idx as size_t)
            if(picked.equals(&ex.answer)) { return true }
            if(ex.correct_index == idx) { return true }
        }
        return false
    }

    // POST /api/onboarding/score — the missing half of G1.
    public func handle_onboarding_score(db : *DbClient, courses_dir : &string, req : &mut http::Request) : http::Response {
        var raw = read_body(req)
        if(raw.size() == 0) {
            var empty = string("empty request body")
            return send_error(400u, &empty)
        }
        var parsed_result = json::parse(raw.to_view())
        if(parsed_result is std::Result.Err) {
            var bad = string("invalid JSON")
            return send_error(400u, &bad)
        }
        var Ok(parsed) = parsed_result else unsafe { unreachable }
        var course_id = json_get_str(&parsed, "course_id")
        if(course_id.size() == 0) { course_id = string("elf") }
        var course = underlayer_repository::load_course(courses_dir, &course_id)
        if(course.id.size() == 0) {
            var nf = string("course not found")
            return send_error(404u, &nf)
        }
        var answers_node = json_get(&parsed, "answers")
        if(answers_node is std::Option.None || course.concepts.size() == 0) {
            var missing = string("answers must be an array")
            return send_error(400u, &missing)
        }
        var Some(answers_val) = answers_node else unsafe { unreachable }
        if(!(answers_val is JsonValue.Array)) {
            var not_array = string("answers must be an array")
            return send_error(400u, &not_array)
        }
        var correct = 0
        var total = 0
        var ai : size_t = 0
        while(ai < underlayer_repository::json_len(answers_val)) {
            var maybe = underlayer_repository::json_at(answers_val, ai)
            if(maybe is std::Option.Some) {
                var Some(item) = maybe else unsafe { unreachable }
                var ex_id = json_get_str(item, "exercise_id")
                var submitted = json_get_str_or_num(item, "answer")
                var ex = underlayer_repository::get_exercise(db, &ex_id)
                if(ex.id.size() > 0) {
                    total = total + 1
                    if(answer_matches(&ex, &submitted)) { correct = correct + 1 }
                }
            }
            ai = ai + 1
        }
        var score : int = 0
        if(total > 0) { score = (correct * 3) / total }
        if(score > 3) { score = 3 }
        var placement = string("beginner")
        var idx : size_t = 0
        if(score == 3) { placement = string("advanced"); idx = (course.concepts.size() * 2) / 3 }
        else if(score == 2) { placement = string("intermediate"); idx = course.concepts.size() / 2 }
        else if(score == 1) { placement = string("developing"); idx = course.concepts.size() / 4 }
        if(idx >= course.concepts.size()) { idx = course.concepts.size() - 1 }
        var start_concept = course.concepts.at_ref(idx).id.copy()

        var body = string("{\"correct\":")
        var c = underlayer_core::int_to_string(correct as i64)
        body.append_string(&c)
        body.append_view(",\"total\":")
        var t = underlayer_core::int_to_string(total as i64)
        body.append_string(&t)
        body.append_view(",\"placement_score\":")
        var s = underlayer_core::int_to_string(score as i64)
        body.append_string(&s)
        body.append_view(",\"placement\":\"")
        body.append_string(&placement)
        body.append_view("\",\"recommended_start\":\"")
        var esc = underlayer_core::json_escape(&start_concept.to_view())
        body.append_string(&esc)
        body.append_view("\"}")
        return send_json_str(&body)
    }

}
