// underlayer_web — Platform analytics handlers (P2 6.2.4, 6.2.5, 6.2.7).
// SQL lives in repository/src/analytics_queries.ch; this file formats JSON only.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // ASCII lowercase a view into a new string (no to_lower in underlayer_core).
    func ascii_lower(sv : *string_view) : string {
        var out = string()
        var i : size_t = 0
        while(i < sv.size()) {
            var c = sv.get(i)
            if(c >= 'A' && c <= 'Z') { c = c + 32 }
            out.append(c)
            i = i + 1
        }
        return out
    }

    // P2 6.2.4: Platform analytics — engagement + retention across all learners
    public func handle_platform_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var r = underlayer_repository::query_platform(&raw db)
        var learners : i64 = 0
        var sessions : i64 = 0
        var correct : i64 = 0
        var attempted : i64 = 0
        var active_7d : i64 = 0
        if(r.rows.size() > 0) {
            var row = r.rows.get_ptr(0)
            var _p0 = row.vals.get_ptr(0).copy()
            learners = underlayer_repository::parse_i64(_p0.to_view())
            var _p1 = row.vals.get_ptr(1).copy()
            sessions = underlayer_repository::parse_i64(_p1.to_view())
            var _p2 = row.vals.get_ptr(2).copy()
            correct = underlayer_repository::parse_i64(_p2.to_view())
            var _p3 = row.vals.get_ptr(3).copy()
            attempted = underlayer_repository::parse_i64(_p3.to_view())
            var _p4 = row.vals.get_ptr(4).copy()
            active_7d = underlayer_repository::parse_i64(_p4.to_view())
        }
        var accuracy : f64 = 0.0
        if(attempted > 0) { accuracy = (correct as f64) / (attempted as f64) }
        var sessions_per_learner : f64 = 0.0
        if(learners > 0) { sessions_per_learner = (sessions as f64) / (learners as f64) }

        var body = string("{\"total_learners\":")
        var _q0 = underlayer_core::int_to_string(learners)
        body.append_string(&_q0)
        body.append_view(",\"total_sessions\":")
        var _q1 = underlayer_core::int_to_string(sessions)
        body.append_string(&_q1)
        body.append_view(",\"sessions_per_learner\":")
        var _q2 = underlayer_learning::f64_to_string(sessions_per_learner)
        body.append_string(&_q2)
        body.append_view(",\"active_learners_7d\":")
        var _q3 = underlayer_core::int_to_string(active_7d)
        body.append_string(&_q3)
        body.append_view(",\"platform_accuracy\":")
        var _q4 = underlayer_learning::f64_to_string(accuracy)
        body.append_string(&_q4)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

    // P2 6.2.5: Cohort analytics — learners grouped by registration week,
    // with per-cohort session activity for group comparison.
    public func handle_cohort_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var cohorts = underlayer_repository::query_cohorts(&raw db)
        var sess = underlayer_repository::query_cohort_sessions(&raw db)

        var body = string("{\"cohorts\":[")
        var i : size_t = 0
        while(i < cohorts.rows.size()) {
            if(i > 0) { body.append_view(",") }
            var row = cohorts.rows.get_ptr(i)
            var _c0 = row.vals.get_ptr(0).copy()
            var _c1 = row.vals.get_ptr(1).copy()
            var week_start = underlayer_repository::parse_i64(_c0.to_view())
            var learners = underlayer_repository::parse_i64(_c1.to_view())
            // Find matching session row
            var active : i64 = 0
            var sessions : i64 = 0
            var si : size_t = 0
            while(si < sess.rows.size()) {
                var srow = sess.rows.get_ptr(si)
                var _s0 = srow.vals.get_ptr(0).copy()
                var _s1 = srow.vals.get_ptr(1).copy()
                var _s2 = srow.vals.get_ptr(2).copy()
                var s_week = underlayer_repository::parse_i64(_s0.to_view())
                if(s_week == week_start) {
                    active = underlayer_repository::parse_i64(_s1.to_view())
                    sessions = underlayer_repository::parse_i64(_s2.to_view())
                    si = sess.rows.size()
                }
                si = si + 1
            }
            var sessions_per : f64 = 0.0
            if(learners > 0) { sessions_per = (sessions as f64) / (learners as f64) }
            var activation : i64 = 0
            if(learners > 0) { activation = (active * 100) / learners }
            body.append_view("{\"week_start\":")
            var _o0 = underlayer_core::int_to_string(week_start)
            body.append_string(&_o0)
            body.append_view(",\"learners\":")
            var _o1 = underlayer_core::int_to_string(learners)
            body.append_string(&_o1)
            body.append_view(",\"active_learners\":")
            var _o2 = underlayer_core::int_to_string(active)
            body.append_string(&_o2)
            body.append_view(",\"activation_pct\":")
            var _o3 = underlayer_core::int_to_string(activation)
            body.append_string(&_o3)
            body.append_view(",\"sessions_per_learner\":")
            var _o4 = underlayer_learning::f64_to_string(sessions_per)
            body.append_string(&_o4)
            body.append_view("}")
            i = i + 1
        }
        body.append_view("]}")
        send_json_str(res, &raw body)
    }

    // P2 6.2.7: Device analytics — mobile vs desktop from login user agents
    public func handle_device_analytics(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        if(learner_id.size() == 0) { learner_id = string("demo") }
        var rows = underlayer_repository::query_login_agents(&raw db, &learner_id)

        var mobile : i64 = 0
        var desktop : i64 = 0
        var tablet : i64 = 0
        var unknown : i64 = 0
        var i : size_t = 0
        while(i < rows.rows.size()) {
            var row = rows.rows.get_ptr(i)
            var _d0 = row.vals.get_ptr(0).copy()
            var _d1 = row.vals.get_ptr(1).copy()
            var logins = underlayer_repository::parse_i64(_d1.to_view())
            var ua = _d0.to_view()
            var ua_lower = ascii_lower(&raw ua)
            var m1 = string("mobile")
            var m2 = string("android")
            var m3 = string("iphone")
            var t1 = string("ipad")
            var t2 = string("tablet")
            if(ua_lower.find(m1.to_view()) != std::NPOS || ua_lower.find(m2.to_view()) != std::NPOS || ua_lower.find(m3.to_view()) != std::NPOS) {
                mobile = mobile + logins
            } else if(ua_lower.find(t1.to_view()) != std::NPOS || ua_lower.find(t2.to_view()) != std::NPOS) {
                tablet = tablet + logins
            } else if(_d0.size() == 0) {
                unknown = unknown + logins
            } else {
                desktop = desktop + logins
            }
            i = i + 1
        }
        var total = mobile + desktop + tablet + unknown

        var body = string("{\"mobile\":")
        var _v0 = underlayer_core::int_to_string(mobile)
        body.append_string(&_v0)
        body.append_view(",\"desktop\":")
        var _v1 = underlayer_core::int_to_string(desktop)
        body.append_string(&_v1)
        body.append_view(",\"tablet\":")
        var _v2 = underlayer_core::int_to_string(tablet)
        body.append_string(&_v2)
        body.append_view(",\"unknown\":")
        var _v3 = underlayer_core::int_to_string(unknown)
        body.append_string(&_v3)
        body.append_view(",\"total_logins\":")
        var _v4 = underlayer_core::int_to_string(total)
        body.append_string(&_v4)
        body.append_view("}")
        send_json_str(res, &raw body)
    }

}
