// underlayer_web — Learner analytics handlers (P2 6.2.6, 6.2.10-6.2.12, 6.2.15).
// SQL lives in repository/src/analytics_queries.ch; this file formats JSON only.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // P2 6.2.6: Temporal analytics — time-of-day + day-of-week session distribution
    public func handle_temporal_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var hours = underlayer_repository::query_temporal_hours(&raw db, &learner_id)
        var weekdays = underlayer_repository::query_temporal_weekdays(&raw db, &learner_id)

        var body = string("{\"by_hour\":[")
        var i : size_t = 0
        while(i < hours.rows.size()) {
            if(i > 0) { body.append_view(",") }
            var row = hours.rows.get_ptr(i)
            body.append_view("{\"hour\":")
            var _h0 = row.vals.get_ptr(0).copy()
            body.append_string(&_h0)
            body.append_view(",\"sessions\":")
            var _h1 = row.vals.get_ptr(1).copy()
            body.append_string(&_h1)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("],\"by_weekday\":[")
        i = 0
        while(i < weekdays.rows.size()) {
            if(i > 0) { body.append_view(",") }
            var row = weekdays.rows.get_ptr(i)
            body.append_view("{\"dow\":")
            var _w0 = row.vals.get_ptr(0).copy()
            body.append_string(&_w0)
            body.append_view(",\"sessions\":")
            var _w1 = row.vals.get_ptr(1).copy()
            body.append_string(&_w1)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // P2 6.2.12: Retention analytics — active days, span, weekly return rate
    public func handle_retention_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var r = underlayer_repository::query_retention(&raw db, &learner_id)
        var weeks = underlayer_repository::query_retention_weeks(&raw db, &learner_id)

        var active_days : i64 = 0
        var first_session : i64 = 0
        var last_session : i64 = 0
        var total_sessions : i64 = 0
        if(r.rows.size() > 0) {
            var row = r.rows.get_ptr(0)
            var _r0 = row.vals.get_ptr(0).copy()
            active_days = underlayer_repository::parse_i64(_r0.to_view())
            var _r1 = row.vals.get_ptr(1).copy()
            first_session = underlayer_repository::parse_i64(_r1.to_view())
            var _r2 = row.vals.get_ptr(2).copy()
            last_session = underlayer_repository::parse_i64(_r2.to_view())
            var _r3 = row.vals.get_ptr(3).copy()
            total_sessions = underlayer_repository::parse_i64(_r3.to_view())
        }
        var active_weeks : i64 = 0
        if(weeks.rows.size() > 0) {
            var wrow = weeks.rows.get_ptr(0)
            var _w0 = wrow.vals.get_ptr(0).copy()
            active_weeks = underlayer_repository::parse_i64(_w0.to_view())
        }
        // Span in weeks (min 1), return rate = active weeks / span weeks
        var span_days = (last_session - first_session) / 86400
        var span_weeks = span_days / 7
        if(span_weeks < 1) { span_weeks = 1 }
        var return_rate : i64 = (active_weeks * 100) / span_weeks

        var body = string("{\"active_days\":")
        var _b0 = underlayer_core::int_to_string(active_days)
        body.append_string(&_b0)
        body.append_view(",\"active_weeks\":")
        var _b1 = underlayer_core::int_to_string(active_weeks)
        body.append_string(&_b1)
        body.append_view(",\"span_weeks\":")
        var _b2 = underlayer_core::int_to_string(span_weeks)
        body.append_string(&_b2)
        body.append_view(",\"return_rate_pct\":")
        var _b3 = underlayer_core::int_to_string(return_rate)
        body.append_string(&_b3)
        body.append_view(",\"total_sessions\":")
        var _b4 = underlayer_core::int_to_string(total_sessions)
        body.append_string(&_b4)
        body.append_view(",\"days_since_last_session\":")
        var now = underlayer_core::current_timestamp()
        var gap = (now - last_session) / 86400
        if(gap < 0) { gap = 0 }
        var _b5 = underlayer_core::int_to_string(gap)
        body.append_string(&_b5)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // P2 6.2.10: Drop-off analytics — started-but-stalled concepts, stalest first
    public func handle_dropoff_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var course_id = string("elf")
        var now = underlayer_core::current_timestamp()
        var rows = underlayer_repository::query_dropoff(&raw db, &learner_id, &course_id)

        var body = string("{\"items\":[")
        var i : size_t = 0
        while(i < rows.rows.size()) {
            if(i > 0) { body.append_view(",") }
            var row = rows.rows.get_ptr(i)
            var _d0 = row.vals.get_ptr(0).copy()
            var _d1 = row.vals.get_ptr(1).copy()
            var _d2 = row.vals.get_ptr(2).copy()
            var _d3 = row.vals.get_ptr(3).copy()
            var _d4 = row.vals.get_ptr(4).copy()
            var last_studied = underlayer_repository::parse_i64(_d4.to_view())
            var days_stale = (now - last_studied) / 86400
            if(days_stale < 0) { days_stale = 0 }
            body.append_view("{\"concept_id\":\"")
            body.append_string(&_d0)
            body.append_view("\",\"status\":\"")
            body.append_string(&_d1)
            body.append_view("\",\"attempts\":")
            body.append_string(&_d2)
            body.append_view(",\"correct\":")
            body.append_string(&_d3)
            body.append_view(",\"days_stale\":")
            var _d5 = underlayer_core::int_to_string(days_stale)
            body.append_string(&_d5)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("],\"count\":")
        var cnt_str = underlayer_core::int_to_string(rows.rows.size() as i64)
        body.append_string(&cnt_str)
        body.append_view(",\"course_id\":\"")
        body.append_string(&course_id)
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

    // P2 6.2.11: Funnel analytics — registered -> attempted -> reviewed -> mastered
    public func handle_funnel_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var r = underlayer_repository::query_funnel(&raw db, &learner_id)
        var registered : i64 = 0
        var attempted : i64 = 0
        var mastered : i64 = 0
        var sessions : i64 = 0
        if(r.rows.size() > 0) {
            var row = r.rows.get_ptr(0)
            var _f0 = row.vals.get_ptr(0).copy()
            registered = underlayer_repository::parse_i64(_f0.to_view())
            var _f1 = row.vals.get_ptr(1).copy()
            attempted = underlayer_repository::parse_i64(_f1.to_view())
            var _f2 = row.vals.get_ptr(2).copy()
            mastered = underlayer_repository::parse_i64(_f2.to_view())
            var _f3 = row.vals.get_ptr(3).copy()
            sessions = underlayer_repository::parse_i64(_f3.to_view())
        }
        // A "reviewed" concept = attempted more than once (came back to it)
        // Approximated by attempts>1 states; counted in SQL above as attempted.
        var body = string("{\"registered\":")
        var _g0 = underlayer_core::int_to_string(registered)
        body.append_string(&_g0)
        body.append_view(",\"concepts_attempted\":")
        var _g1 = underlayer_core::int_to_string(attempted)
        body.append_string(&_g1)
        body.append_view(",\"concepts_mastered\":")
        var _g2 = underlayer_core::int_to_string(mastered)
        body.append_string(&_g2)
        body.append_view(",\"sessions\":")
        var _g3 = underlayer_core::int_to_string(sessions)
        body.append_string(&_g3)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // P2 6.2.15: Comparative analytics — me vs platform average accuracy
    public func handle_comparative_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var r = underlayer_repository::query_comparative(&raw db, &learner_id)
        var accs = underlayer_repository::query_learner_accuracies(&raw db)

        var my_correct : i64 = 0
        var my_attempts : i64 = 0
        var all_correct : i64 = 0
        var all_attempts : i64 = 0
        var learner_count : i64 = 0
        if(r.rows.size() > 0) {
            var row = r.rows.get_ptr(0)
            var _c0 = row.vals.get_ptr(0).copy()
            my_correct = underlayer_repository::parse_i64(_c0.to_view())
            var _c1 = row.vals.get_ptr(1).copy()
            my_attempts = underlayer_repository::parse_i64(_c1.to_view())
            var _c2 = row.vals.get_ptr(2).copy()
            all_correct = underlayer_repository::parse_i64(_c2.to_view())
            var _c3 = row.vals.get_ptr(3).copy()
            all_attempts = underlayer_repository::parse_i64(_c3.to_view())
            var _c4 = row.vals.get_ptr(4).copy()
            learner_count = underlayer_repository::parse_i64(_c4.to_view())
        }

        var my_acc : f64 = 0.0
        if(my_attempts > 0) { my_acc = (my_correct as f64) / (my_attempts as f64) }
        var avg_acc : f64 = 0.0
        if(all_attempts > 0) { avg_acc = (all_correct as f64) / (all_attempts as f64) }

        // Percentile: share of peers with strictly lower accuracy
        var peers_below : i64 = 0
        var peers_total : i64 = 0
        var ai : size_t = 0
        while(ai < accs.rows.size()) {
            var arow = accs.rows.get_ptr(ai)
            var _a0 = arow.vals.get_ptr(0).copy()
            var _a1 = arow.vals.get_ptr(1).copy()
            var _a2 = arow.vals.get_ptr(2).copy()
            var cid = _a0
            var c = underlayer_repository::parse_i64(_a1.to_view())
            var a = underlayer_repository::parse_i64(_a2.to_view())
            if(a > 0) {
                var peer_acc = (c as f64) / (a as f64)
                var mine = string("demo")
                if(!cid.equals(&mine)) {
                    peers_total = peers_total + 1
                    if(peer_acc < my_acc) { peers_below = peers_below + 1 }
                }
            }
            ai = ai + 1
        }
        var percentile : i64 = 0
        if(peers_total > 0) { percentile = (peers_below * 100) / peers_total }

        var body = string("{\"my_accuracy\":")
        var _m0 = underlayer_learning::f64_to_string(my_acc)
        body.append_string(&_m0)
        body.append_view(",\"platform_avg_accuracy\":")
        var _m1 = underlayer_learning::f64_to_string(avg_acc)
        body.append_string(&_m1)
        body.append_view(",\"percentile\":")
        var _m2 = underlayer_core::int_to_string(percentile)
        body.append_string(&_m2)
        body.append_view(",\"peer_count\":")
        var _m3 = underlayer_core::int_to_string(peers_total)
        body.append_string(&_m3)
        body.append_view(",\"total_attempts\":")
        var _m4 = underlayer_core::int_to_string(my_attempts)
        body.append_string(&_m4)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

}
