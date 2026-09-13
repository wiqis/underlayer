// underlayer_web — Weakness dashboard and export handlers.
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_learning::WeaknessReport
using underlayer_learning::WeaknessCluster
using underlayer_learning::WeaknessHistoryEntry
using underlayer_learning::detect_weaknesses
using underlayer_learning::cluster_weaknesses
using underlayer_learning::compute_weakness_trend
using underlayer_learning::track_weakness_resolution

public namespace underlayer_web {

    // 1.4.21: Weakness dashboard — all weak concepts with severity and trend
    public func handle_weakness_dashboard(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")
        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
        var weaknesses = detect_weaknesses(&raw states)
        var clusters = cluster_weaknesses(&raw weaknesses)

        var body = string("{\"weaknesses\":[")
        var i : size_t = 0
        while(i < weaknesses.size()) {
            if(i > 0) { body.append_view(",") }
            var w = weaknesses.get_ptr(i)
            body.append_view("{\"concept_id\":\"")
            body.append_string(&w.concept_id)
            body.append_view("\",\"accuracy\":")
            var acc_out = underlayer_learning::f64_to_string(w.accuracy)
            body.append_string(&acc_out)
            body.append_view(",\"severity\":")
            var sev_out = underlayer_core::int_to_string(w.severity as i64)
            body.append_string(&sev_out)
            body.append_view(",\"status\":\"")
            body.append_string(&w.status)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("],\"clusters\":[")
        i = 0
        while(i < clusters.size()) {
            if(i > 0) { body.append_view(",") }
            var c = clusters.get_ptr(i)
            body.append_view("{\"module\":\"")
            body.append_string(&c.module_prefix)
            body.append_view("\",\"count\":")
            var cnt_out = underlayer_core::int_to_string(c.count as i64)
            body.append_string(&cnt_out)
            body.append_view(",\"avg_severity\":")
            var avg_out = underlayer_learning::f64_to_string(c.avg_severity)
            body.append_string(&avg_out)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // 1.4.23: Weakness export — download weakness report as JSON
    public func handle_weakness_export(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = string("demo")
        var course_id = string("elf")
        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
        var weaknesses = detect_weaknesses(&raw states)

        var body = string("[")
        var i : size_t = 0
        while(i < weaknesses.size()) {
            if(i > 0) { body.append_view(",") }
            var w = weaknesses.get_ptr(i)
            body.append_view("{\"concept_id\":\"")
            body.append_string(&w.concept_id)
            body.append_view("\",\"accuracy\":")
            var acc_out = underlayer_learning::f64_to_string(w.accuracy)
            body.append_string(&acc_out)
            body.append_view(",\"severity\":")
            var sev_out = underlayer_core::int_to_string(w.severity as i64)
            body.append_string(&sev_out)
            body.append_view(",\"total_attempts\":")
            var att_out = underlayer_core::int_to_string(w.total_attempts as i64)
            body.append_string(&att_out)
            body.append_view(",\"correct_count\":")
            var cor_out = underlayer_core::int_to_string(w.correct_count as i64)
            body.append_string(&cor_out)
            body.append_view(",\"status\":\"")
            body.append_string(&w.status)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("]")
        send_json_str(res, &raw body)
    }

}
