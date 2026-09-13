// underlayer_web — Progress and course progress handlers.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_course_progress(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var path = req.path.to_view()
        var segments = underlayer_core::path_segments(&path)
        var course_id_raw = string("elf")
        if(segments.size() >= 4) {
            var sv = segments.get_ptr(3)
            var i : size_t = 0
            while(i < sv.size()) { course_id_raw.append(sv.get(i)); i = i + 1 }
        }
        var learner_id = string("demo")
        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id_raw)
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var body = std::string("{\"course_id\":\"")
        body.append_string(&course_id_raw)
        body.append_view("\",\"health\":")
        var health_str = underlayer_core::int_to_string((health.health_score * 100.0) as i64)
        body.append_string(&health_str)
        body.append_view(",\"mastered\":")
        var mastered_str = underlayer_core::int_to_string(health.mastered as i64)
        body.append_string(&mastered_str)
        body.append_view(",\"learning\":")
        var learning_str = underlayer_core::int_to_string(health.learning as i64)
        body.append_string(&learning_str)
        body.append_view(",\"reviewing\":")
        var reviewing_str = underlayer_core::int_to_string(health.reviewing as i64)
        body.append_string(&reviewing_str)
        body.append_view(",\"unlearned\":")
        var unlearned_str = underlayer_core::int_to_string(health.unlearned as i64)
        body.append_string(&unlearned_str)
        body.append_view(",\"concepts\":[")
        var ci : size_t = 0
        while(ci < states.size()) {
            if(ci > 0) { body.append_view(",") }
            var s = states.get_ptr(ci)
            body.append_view("{\"concept_id\":\"")
            body.append_string(&s.concept_id)
            body.append_view("\",\"status\":\"")
            body.append_string(&s.status)
            body.append_view("\",\"attempts\":")
            var a_str = underlayer_core::int_to_string(s.attempts as i64)
            body.append_string(&a_str)
            body.append_view(",\"correct\":")
            var c_str = underlayer_core::int_to_string(s.correct as i64)
            body.append_string(&c_str)
            body.append_view("}")
            ci = ci + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    public func handle_progress(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")

        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
        var health = underlayer_learning::compute_knowledge_health(&raw states)

        var body = std::string("{\"learner_id\":\"")
        body.append_string(&learner_id)
        body.append_view("\",\"course_id\":\"")
        body.append_string(&course_id)
        body.append_view("\",\"health\":")
        var health_str = underlayer_core::int_to_string((health.health_score * 100.0) as i64)
        body.append_string(&health_str)
        body.append_view(",\"mastered\":")
        var mastered_str = underlayer_core::int_to_string(health.mastered as i64)
        body.append_string(&mastered_str)
        body.append_view(",\"learning\":")
        var learning_str = underlayer_core::int_to_string(health.learning as i64)
        body.append_string(&learning_str)
        body.append_view(",\"reviewing\":")
        var reviewing_str = underlayer_core::int_to_string(health.reviewing as i64)
        body.append_string(&reviewing_str)
        body.append_view(",\"unlearned\":")
        var unlearned_str = underlayer_core::int_to_string(health.unlearned as i64)
        body.append_string(&unlearned_str)
        body.append_view(",\"concepts\":[")

        var i : size_t = 0
        while(i < states.size()) {
            if(i > 0) { body.append_view(",") }
            var s = states.get_ptr(i)
            body.append_view("{\"concept_id\":\"")
            body.append_string(&s.concept_id)
            body.append_view("\",\"status\":\"")
            body.append_string(&s.status)
            body.append_view("\",\"attempts\":")
            var attempts_str = underlayer_core::int_to_string(s.attempts as i64)
            body.append_string(&attempts_str)
            body.append_view(",\"correct\":")
            var correct_str = underlayer_core::int_to_string(s.correct as i64)
            body.append_string(&correct_str)
            body.append_view(",\"streak\":")
            var streak_str = underlayer_core::int_to_string(s.streak as i64)
            body.append_string(&streak_str)
            body.append_view("}")
            i = i + 1
        }

        body.append_view("]}")
        send_json_str(res, &raw body)
    }

}
